// ucsbece154b_controller.v
// ECE 154B, RISC-V pipelined processor 
// All Rights Reserved
// Copyright (c) 2024 UCSB ECE
// Distribution Prohibited


module ucsbece154b_controller (
    input                clk, reset,
    input         [6:0]  op_i, 
    input         [2:0]  funct3_i,
    input                funct7b5_i,
    input         [4:0]  Rs1D_i,
    input         [4:0]  Rs2D_i,
    input         [4:0]  Rs1E_i,
    input         [4:0]  Rs2E_i,
    input         [4:0]  RdE_i,
    input         [4:0]  RdM_i,
    input         [4:0]  RdW_i,
    input               Ready_F,
    input               BusyF,             // NEW: Busy signal from icache
    output wire          StallF_o,  
    output wire          StallD_o,
    output wire          FlushD_o,
    output wire    [2:0] ImmSrcD_o,
    input           MisspredictE_i,
    output reg     [2:0] ALUControlE_o,
    output reg           ALUSrcE_o,
    output wire          FlushE_o,
    output reg     [1:0] ForwardAE_o,
    output reg     [1:0] ForwardBE_o,
    output reg           MemWriteM_o,
    output reg           RegWriteW_o,
    output reg     [1:0] ResultSrcW_o, 
    output reg     [1:0] ResultSrcM_o, 
    output reg           BranchE_o,
    output reg           JumpE_o,
    output reg           BranchTypeE_o
);

`include "ucsbece154b_defines.vh"

// Decoder signals
wire RegWriteD, MemWriteD, JumpD, BranchD, ALUSrcD;
reg BranchTypeD;
wire [1:0] ResultSrcD; 
reg [2:0] ALUControlD;
wire [1:0] ALUOpD;
reg [11:0] maindecoderD;

assign {RegWriteD, 
        ImmSrcD_o,
        ALUSrcD,
        MemWriteD,
        ResultSrcD,
        BranchD, 
        ALUOpD,
        JumpD} = maindecoderD;

always @ * begin
  case (op_i)
    instr_lw_op:        maindecoderD = 12'b1_000_1_0_01_0_00_0;       
    instr_sw_op:        maindecoderD = 12'b0_001_1_1_00_0_00_0; 
    instr_Rtype_op:     maindecoderD = 12'b1_xxx_0_0_00_0_10_0;  
    instr_branch_op:    maindecoderD = 12'b0_010_0_0_00_1_01_0;  
    instr_ItypeALU_op:  maindecoderD = 12'b1_000_1_0_00_0_10_0; 
    instr_jal_op:       maindecoderD = 12'b1_011_x_0_10_0_xx_1; 
    instr_lui_op:       maindecoderD = 12'b1_100_x_0_11_0_xx_0; 
    instr_jalr_op:      maindecoderD = 12'b1_000_x_0_10_0_xx_1;  
    default:            maindecoderD = 12'b0_xxx_x_0_xx_0_xx_0; 
  endcase
end

wire RtypeSubD = funct7b5_i & op_i[5];

always @ * begin
  case(ALUOpD)
    ALUop_mem:       ALUControlD = ALUcontrol_add;
    ALUop_beqbne:    ALUControlD = ALUcontrol_sub;
    ALUop_other: 
      case(funct3_i)
        instr_addsub_funct3: ALUControlD = RtypeSubD ? ALUcontrol_sub : ALUcontrol_add;
        instr_slt_funct3:    ALUControlD = ALUcontrol_slt;  
        instr_or_funct3:     ALUControlD = ALUcontrol_or;  
        instr_and_funct3:    ALUControlD = ALUcontrol_and;  
        default:             ALUControlD = 3'bxxx;
      endcase
    default: ALUControlD = 3'bxxx;
  endcase
end

always @ * begin
  case(funct3_i)
    instr_beq_funct3: BranchTypeD = 1'b0;
    instr_bne_funct3: BranchTypeD = 1'b1;
    default:          BranchTypeD = 1'bx;
  endcase
end

// EXECUTE STAGE
reg RegWriteE, MemWriteE;
reg [1:0] ResultSrcE;

always @(posedge clk) begin
  if (FlushE_o | reset) begin
    RegWriteE     <=  1'b0;
    ResultSrcE    <=  2'b0;
    MemWriteE     <=  1'b0;
    JumpE_o       <=  1'b0;
    BranchE_o     <=  1'b0;
    ALUControlE_o <=  3'b0;
    ALUSrcE_o     <=  1'b0;
    BranchTypeE_o <=  1'b0;
  end else begin
    RegWriteE     <= RegWriteD;
    ResultSrcE    <= ResultSrcD;
    MemWriteE     <= MemWriteD;
    JumpE_o       <= JumpD;
    BranchE_o     <= BranchD;
    ALUControlE_o <= ALUControlD;
    ALUSrcE_o     <= ALUSrcD; 
    BranchTypeE_o <= BranchTypeD;
  end
end

// MEMORY STAGE
reg RegWriteM;

always @(posedge clk) begin
  if (reset) begin 
    RegWriteM    <= 1'b0;
    ResultSrcM_o <= 2'b0;
    MemWriteM_o  <= 1'b0;
  end else begin
    RegWriteM    <= RegWriteE;
    ResultSrcM_o <= ResultSrcE;
    MemWriteM_o  <= MemWriteE;
  end
end

// WRITEBACK STAGE
always @(posedge clk) begin
  if (reset) begin 
    RegWriteW_o  <= 1'b0;
    ResultSrcW_o <= 2'b0;
  end else begin
    RegWriteW_o  <= RegWriteM;
    ResultSrcW_o <= ResultSrcM_o;
  end
end

// FORWARDING
always @ * begin
  if ((Rs1E_i == RdM_i) & RegWriteM & (Rs1E_i != 0))
    ForwardAE_o = forward_mem;
  else if ((Rs1E_i == RdW_i) & RegWriteW_o & (Rs1E_i != 0))
    ForwardAE_o = forward_wb;
  else
    ForwardAE_o = forward_ex;
end

always @ * begin
  if ((Rs2E_i == RdM_i) & RegWriteM & (Rs2E_i != 0))
    ForwardBE_o = forward_mem;
  else if ((Rs2E_i == RdW_i) & RegWriteW_o & (Rs2E_i != 0))
    ForwardBE_o = forward_wb;
  else
    ForwardBE_o = forward_ex;
end

// STALLING
wire lwStall = (ResultSrcE == 1) & ((Rs1D_i == RdE_i) | (Rs2D_i == RdE_i)) & (RdE_i != 0);
assign StallF_o = lwStall || (BusyF && ~Ready_F);  // NEW
assign StallD_o = lwStall || (BusyF && ~Ready_F);  // NEW
assign FlushD_o = MisspredictE_i;
assign FlushE_o = lwStall | MisspredictE_i;

endmodule

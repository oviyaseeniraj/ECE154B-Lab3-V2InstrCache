// ucsbece154b_top_tb.v - Verilog 2001 Compliant Testbench using text.dat with top-level DUT

`define SIM
`define ASSERT(CONDITION, MESSAGE) if ((CONDITION)==1'b1); else begin $error($sformatf MESSAGE); end

module ucsbece154b_top_tb ();

reg clk = 1;
always #1 clk <= ~clk;
reg reset;

integer jumptotal = 0;
integer jumppredictedcorrectly = 0;
integer branchtotal = 0;
integer branchpredictedcorrectly = 0;

ucsbece154b_top top (
    .clk(clk), .reset(reset)
);

wire [31:0] reg_zero = top.riscv.dp.rf.zero;
wire [31:0] reg_ra = top.riscv.dp.rf.ra;
wire [31:0] reg_sp = top.riscv.dp.rf.sp;
wire [31:0] reg_gp = top.riscv.dp.rf.gp;
wire [31:0] reg_tp = top.riscv.dp.rf.tp;
wire [31:0] reg_t0 = top.riscv.dp.rf.t0;
wire [31:0] reg_t1 = top.riscv.dp.rf.t1;
wire [31:0] reg_t2 = top.riscv.dp.rf.t2;
wire [31:0] reg_s0 = top.riscv.dp.rf.s0;
wire [31:0] reg_s1 = top.riscv.dp.rf.s1;
wire [31:0] reg_a0 = top.riscv.dp.rf.a0;
wire [31:0] reg_a1 = top.riscv.dp.rf.a1;
wire [31:0] reg_a2 = top.riscv.dp.rf.a2;
wire [31:0] reg_a3 = top.riscv.dp.rf.a3;
wire [31:0] reg_a4 = top.riscv.dp.rf.a4;
wire [31:0] reg_a5 = top.riscv.dp.rf.a5;
wire [31:0] reg_a6 = top.riscv.dp.rf.a6;
wire [31:0] reg_a7 = top.riscv.dp.rf.a7;
wire [31:0] reg_s2 = top.riscv.dp.rf.s2;
wire [31:0] reg_s3 = top.riscv.dp.rf.s3;
wire [31:0] reg_s4 = top.riscv.dp.rf.s4;
wire [31:0] reg_s5 = top.riscv.dp.rf.s5;
wire [31:0] reg_s6 = top.riscv.dp.rf.s6;
wire [31:0] reg_s7 = top.riscv.dp.rf.s7;
wire [31:0] reg_s8 = top.riscv.dp.rf.s8;
wire [31:0] reg_s9 = top.riscv.dp.rf.s9;
wire [31:0] reg_s10 = top.riscv.dp.rf.s10;
wire [31:0] reg_s11 = top.riscv.dp.rf.s11;
wire [31:0] reg_t3 = top.riscv.dp.rf.t3;
wire [31:0] reg_t4 = top.riscv.dp.rf.t4;
wire [31:0] reg_t5 = top.riscv.dp.rf.t5;
wire [31:0] reg_t6 = top.riscv.dp.rf.t6;

wire [31:0] fetchpc = top.riscv.dp.PCPlus4W;

integer i;
integer fetches = 0;
integer hits = 0;
integer misses = 0;

// SDRAM model preload
reg [31:0] memory [0:255];
reg [31:0] pending_address;
reg [5:0] delay_counter;
reg [1:0] word_index;
reg sdram_busy;
reg ReadEnable = 0;
reg [31:0] ReadData;

initial begin
    $readmemh("text.dat", memory);

    $display("Begin simulation.");
    reset = 1;
    ReadEnable = 0;
    @(negedge clk);
    @(negedge clk);
    reset = 0;

    for (i = 0; i < 10000; i = i + 1) begin
        @(negedge clk);

        if (top.riscv.dp.BranchE_i) branchtotal++;
        if (top.riscv.dp.JumpE_i) jumptotal++;
        if (~top.riscv.dp.MisspredictE_o & top.riscv.dp.BranchE_i) branchpredictedcorrectly++;
        if (~top.riscv.dp.MisspredictE_o & top.riscv.dp.JumpE_i) jumppredictedcorrectly++;

        if (top.icache.ReadEnable) begin
            fetches = fetches + 1;
            if (top.icache.Ready) begin
                hits = hits + 1;
            end else if (top.icache.MemReadRequest && !sdram_busy) begin
                misses = misses + 1;
                sdram_busy = 1;
                pending_address = top.icache.MemReadAddress;
                delay_counter = 40;
                word_index = 0;
            end
        end

        if (sdram_busy) begin
            if (delay_counter > 0) begin
                delay_counter = delay_counter - 1;
            end else begin
                top.icache.MemDataIn = memory[(pending_address >> 2) + word_index];
                top.icache.MemDataReady = 1;
                word_index = word_index + 1;
                if (word_index == 4) begin
                    sdram_busy = 0;
                    top.icache.MemDataReady = 0;
                end
            end
        end else begin
            top.icache.MemDataReady = 0;
        end
    end

    $display("End simulation.");
    $display("--- Performance Stats ---");
    $display("Cache Fetches: %0d", fetches);
    $display("Cache Hits:    %0d", hits);
    $display("Cache Misses:  %0d", misses);
    $stop;
end

endmodule

`undef ASSERT
// ucsbece154b_top_tb.v
// All Rights Reserved
// Copyright (c) 2024 UCSB ECE
// Distribution Prohibited

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

// OLD: variables never initialized, so output was 'x'
// integer fetches, hits, misses;
// NEW: initialize hit/miss/fetch counters
integer fetches = 0;
integer hits = 0;
integer misses = 0;

initial begin
    $display("Begin simulation.");
    reset = 1;
    @(negedge clk);
    @(negedge clk);
    reset = 0;

    // Test for program 
    for (i = 0; i < 10000; i = i + 1) begin
        @(negedge clk);

        // counter for jumps and branches
        if (top.riscv.dp.BranchE_i) branchtotal++;
        if (top.riscv.dp.JumpE_i) jumptotal++;
        if (~top.riscv.dp.MisspredictE_o & top.riscv.dp.BranchE_i) branchpredictedcorrectly++;
        if (~top.riscv.dp.MisspredictE_o & top.riscv.dp.JumpE_i) jumppredictedcorrectly++;

        // Count cache accesses (fetches, hits, misses)
        if (top.icache.ReadEnable) begin
            fetches++;
            if (top.icache.Ready) begin
                hits++;
            end else if (top.icache.MemReadRequest) begin
                misses++;
            end
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

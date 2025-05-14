// ucsbece154b_top_tb.v - Verilog 2001 Compliant Testbench for ICache

`define SIM
`define ASSERT(CONDITION, MESSAGE) if ((CONDITION)==1'b1); else begin $error($sformatf MESSAGE); end

module ucsbece154b_top_tb();

reg clk = 1;
always #1 clk = ~clk;
reg reset;

integer i;
integer fetches;
integer hits;
integer misses;
reg last_readenable;

// DUT
wire [31:0] Instruction;
wire Ready, Busy;
reg ReadEnable;
reg [31:0] ReadAddress;
wire [31:0] MemReadAddress;
wire MemReadRequest;
reg [31:0] MemDataIn;
reg MemDataReady;

ucsbece154_icache icache_inst (
    .Clk(clk),
    .Reset(reset),
    .ReadEnable(ReadEnable),
    .ReadAddress(ReadAddress),
    .Instruction(Instruction),
    .Ready(Ready),
    .Busy(Busy),
    .MemReadAddress(MemReadAddress),
    .MemReadRequest(MemReadRequest),
    .MemDataIn(MemDataIn),
    .MemDataReady(MemDataReady)
);

// SDRAM model (fake memory controller)
reg [31:0] memory [0:255]; // 1KB instruction memory
reg [5:0] delay_counter;
reg [1:0] word_index;
reg [31:0] pending_address;
reg sdram_busy;

initial begin
    // preload memory
    for (i = 0; i < 256; i = i + 1)
        memory[i] = 32'h00000013 + i; // dummy nop-like instrs

    // init
    reset = 1;
    ReadEnable = 0;
    ReadAddress = 0;
    MemDataIn = 0;
    MemDataReady = 0;
    fetches = 0;
    hits = 0;
    misses = 0;
    last_readenable = 0;
    delay_counter = 0;
    word_index = 0;
    sdram_busy = 0;
    @(negedge clk);
    @(negedge clk);
    reset = 0;

    for (i = 0; i < 100; i = i + 1) begin
        @(negedge clk);
        ReadEnable = 1;
        ReadAddress = i * 4;

        if (ReadEnable && !last_readenable)
            fetches = fetches + 1;
        if (Ready)
            hits = hits + 1;
        if (MemReadRequest && !sdram_busy) begin
            misses = misses + 1;
            sdram_busy = 1;
            pending_address = MemReadAddress;
            delay_counter = 40;
            word_index = 0;
        end

        if (sdram_busy) begin
            if (delay_counter > 0) begin
                delay_counter = delay_counter - 1;
            end else begin
                MemDataIn = memory[(pending_address >> 2) + word_index];
                MemDataReady = 1;
                word_index = word_index + 1;
                if (word_index == 4) begin
                    sdram_busy = 0;
                    MemDataReady = 0;
                end
            end
        end else begin
            MemDataReady = 0;
        end

        last_readenable = ReadEnable;
    end

    $display("--- Simulation Complete ---");
    $display("Fetches: %d", fetches);
    $display("Hits:    %d", hits);
    $display("Misses:  %d", misses);
    $stop;
end

endmodule

`undef ASSERT
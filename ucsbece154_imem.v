// ucsbece154_imem.v
// All Rights Reserved
// Copyright (c) 2024 UCSB ECE
// Distribution Prohibited

`define MIN(A,B) (((A)<(B))?(A):(B))

module ucsbece154_imem #(
    parameter TEXT_SIZE = 64,
    parameter BLOCK_WORDS = 4,          // words per burst (must match cache)
    parameter T0_DELAY = 40             // first word delay (cycles)
) (
    input wire clk,
    input wire reset,

    input wire ReadRequest,
    input wire [31:0] ReadAddress,

    output reg [31:0] DataIn,
    output reg DataReady
);

// === BRAM: Initialize memory ===
reg [31:0] TEXT [0:TEXT_SIZE-1];
initial $readmemh("text.dat", TEXT);

// === Address Range Logic ===
localparam TEXT_START = 32'h00010000;
localparam TEXT_END   = `MIN( TEXT_START + (TEXT_SIZE*4), 32'h10000000);
localparam TEXT_ADDRESS_WIDTH = $clog2(TEXT_SIZE);

wire [31:0] a_i = ReadAddress;
wire [TEXT_ADDRESS_WIDTH-1:0] text_address = a_i[2 +: TEXT_ADDRESS_WIDTH] - (TEXT_START[2 +: TEXT_ADDRESS_WIDTH]);
wire text_enable = (TEXT_START <= a_i) && (a_i < TEXT_END);
wire [31:0] rd_o = text_enable ? TEXT[text_address] : {32{1'bz}};

`ifdef SIM
always @ * begin
    if (a_i[1:0] != 2'b00)
        $warning("Attempted to access invalid address 0x%h. Address coerced to 0x%h.", a_i, (a_i & ~32'b11));
end
`endif

// === NEW: Burst FSM State ===
integer counter = 0;
reg bursting = 0;
reg [1:0] burst_index = 0;
reg [31:0] base_address; // word-aligned start of burst

always @(posedge clk) begin
    if (reset) begin
        DataIn <= 32'b0;
        DataReady <= 0;
        counter <= T0_DELAY;
        burst_index <= 0;
        bursting <= 0;
    end else begin
        if (ReadRequest && !bursting) begin
            // Start burst
            base_address <= ReadAddress & 32'hFFFFFFF0; // NEW: Align to 16-byte block
            counter <= T0_DELAY;
            burst_index <= 0;
            bursting <= 1;
            DataReady <= 0;
        end else if (bursting) begin
            if (counter > 0) begin
                counter <= counter - 1;
                DataReady <= 0;
            end else begin
                // NEW: Send word i of burst
                DataIn <= TEXT[(base_address - TEXT_START) >> 2 + burst_index];
                DataReady <= 1;
                burst_index <= burst_index + 1;

                if (burst_index == BLOCK_WORDS - 1) begin
                    bursting <= 0;
                end
            end
        end else begin
            // Idle
            DataReady <= 0;
        end
    end
end

endmodule

`undef MIN

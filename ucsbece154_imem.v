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
   
wire [31:0] a_i = ReadAddress;//address to memory map read address

wire [31:0] rd_o;// read data from memory

// Implement SDRAM interface here

// sends first word of data to cache controller after T0_DELAY cycles
// raise DataReady when data is available
// bus = ReadAddress, DataIn, ReadRequest, and DataReady signals
// keep receiving readrequest=1 and valid readdress until data is ready
always @(posedge clk) begin
    if (reset) begin
        DataReady <= 1'b0;
        DataIn <= 32'b0;
    end else begin
        if (ReadRequest) begin
            // wait T0_DELAY cycles before sending data
            if (T0_DELAY > 0) begin
                T0_DELAY <= T0_DELAY - 1;
            end else begin
                DataIn <= rd_o;
                DataReady <= 1'b1;
            end
        end else begin
            DataReady <= 1'b0;
        end
    end
end


// instantiate/initialize BRAM
reg [31:0] TEXT [0:TEXT_SIZE-1];

// initialize memory with test program. Change this with your file for running custom code
initial $readmemh("text.dat", TEXT);

// calculate address bounds for memory
localparam TEXT_START = 32'h00010000;
localparam TEXT_END   = `MIN( TEXT_START + (TEXT_SIZE*4), 32'h10000000);

// calculate address width
localparam TEXT_ADDRESS_WIDTH = $clog2(TEXT_SIZE);

// create flags to specify whether in-range 
wire text_enable = (TEXT_START <= a_i) && (a_i < TEXT_END);

// create addresses 
wire [TEXT_ADDRESS_WIDTH-1:0] text_address = a_i[2 +: TEXT_ADDRESS_WIDTH]-(TEXT_START[2 +: TEXT_ADDRESS_WIDTH]);

// get read-data 
wire [31:0] text_data = TEXT[ text_address ];

// set rd_o iff a_i is in range 
assign rd_o =
    text_enable ? text_data : 
    {32{1'bz}}; // not driven by this memory

`ifdef SIM
always @ * begin
    if (a_i[1:0]!=2'b0)
        $warning("Attempted to access invalid address 0x%h. Address coerced to 0x%h.", a_i, (a_i&(~32'b11)));
end
`endif

endmodule

`undef MIN

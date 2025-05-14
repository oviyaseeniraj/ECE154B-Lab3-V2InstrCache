// ucsbece154_imem.v
// All Rights Reserved
// Copyright (c) 2024 UCSB ECE
// Distribution Prohibited

`define MIN(A,B) (((A)<(B))?(A):(B))

module ucsbece154_imem #(
    parameter TEXT_SIZE = 64,
    parameter BLOCK_WORDS = 4,
    parameter T0_DELAY = 40
)(
    input wire clk,
    input wire reset,

    input wire ReadRequest,
    input wire [31:0] ReadAddress,

    output reg [31:0] DataIn,
    output reg DataReady
);

wire [31:0] a_i = ReadAddress;
wire [31:0] rd_o;

reg [31:0] TEXT [0:TEXT_SIZE-1];
initial $readmemh("text.dat", TEXT);

localparam TEXT_START = 32'h00010000;
localparam TEXT_END   = `MIN( TEXT_START + (TEXT_SIZE*4), 32'h10000000);
localparam TEXT_ADDRESS_WIDTH = $clog2(TEXT_SIZE);

wire text_enable = (TEXT_START <= a_i) && (a_i < TEXT_END);
wire [TEXT_ADDRESS_WIDTH-1:0] text_address = a_i[2 +: TEXT_ADDRESS_WIDTH]-(TEXT_START[2 +: TEXT_ADDRESS_WIDTH]);
wire [31:0] text_data = TEXT[text_address];
assign rd_o = text_enable ? text_data : {32{1'bz}};

`ifdef SIM
always @ * begin
    if (a_i[1:0]!=2'b0)
        $warning("Attempted to access invalid address 0x%h. Address coerced to 0x%h.", a_i, (a_i&(~32'b11)));
end
`endif

// OLD:
// integer counter = T0_DELAY;
// always @(posedge clk) begin
//     if (reset) begin
//         DataReady <= 1'b0;
//         DataIn <= 32'b0;
//     end else begin
//         if (ReadRequest) begin
//             if (counter > 0) begin
//                 counter <= counter - 1;
//             end else begin
//                 DataIn <= rd_o;
//                 DataReady <= 1'b1;
//             end
//         end else begin
//             DataReady <= 1'b0;
//         end
//     end
// end

// NEW:
reg [5:0] counter;
reg [1:0] burst_index;
reg [31:0] base_address;
reg burst_active;

always @(posedge clk) begin
    if (reset) begin
        DataReady <= 1'b0;
        DataIn <= 32'b0;
        counter <= T0_DELAY;
        burst_index <= 0;
        base_address <= 0;
        burst_active <= 0;
    end else begin
        if (ReadRequest && !burst_active) begin
            base_address <= {ReadAddress[31:2], 2'b00}; // align to block start
            counter <= T0_DELAY;
            burst_index <= 0;
            burst_active <= 1;
            DataReady <= 0;
        end else if (burst_active) begin
            if (counter > 0) begin
                counter <= counter - 1;
                DataReady <= 0;
            end else begin
                DataIn <= TEXT[(base_address >> 2) + burst_index];
                DataReady <= 1;

                if (burst_index == BLOCK_WORDS - 1) begin
                    burst_active <= 0;
                end else begin
                    burst_index <= burst_index + 1;
                    base_address <= base_address + 4;
                    counter <= 1; // Tburst = 1
                end
            end
        end else begin
            DataReady <= 0;
        end
    end
end

endmodule

`undef MIN

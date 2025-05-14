// ucsbece154_imem.v - Verilog 2001 Compliant SDRAM Memory Model

module ucsbece154_imem (
    clk,
    reset,
    ReadRequest,
    ReadAddress,
    DataIn,
    DataReady
);

parameter TEXT_SIZE = 256;
parameter BLOCK_WORDS = 4;          // words per burst (must match cache)
parameter T0_DELAY = 40;            // first word delay (cycles)

input clk;
input reset;
input ReadRequest;
input [31:0] ReadAddress;
output reg [31:0] DataIn;
output reg DataReady;

reg [31:0] memory [0:TEXT_SIZE-1];
reg [1:0] word_counter;
reg [5:0] delay_counter;
reg [31:0] base_address;
reg [1:0] state;

parameter IDLE = 2'd0;
parameter T0_WAIT = 2'd1;
parameter BURST = 2'd2;

function [31:0] word_addr;
    input [31:0] addr;
    begin
        word_addr = addr >> 2; // convert byte address to word index
    end
endfunction

integer i;

always @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        DataReady <= 0;
        DataIn <= 0;
        delay_counter <= 0;
        word_counter <= 0;
        for (i = 0; i < TEXT_SIZE; i = i + 1)
            memory[i] <= 32'h00000013 + i; // preload dummy instructions
    end else begin
        DataReady <= 0;
        case (state)
            IDLE: begin
                if (ReadRequest) begin
                    base_address <= {ReadAddress[31:(2 + $clog2(BLOCK_WORDS))], {(2 + $clog2(BLOCK_WORDS)){1'b0}}};
                    delay_counter <= 0;
                    word_counter <= 0;
                    state <= T0_WAIT;
                end
            end

            T0_WAIT: begin
                if (delay_counter == T0_DELAY) begin
                    DataIn <= memory[word_addr(base_address)];
                    DataReady <= 1;
                    word_counter <= 1;
                    state <= BURST;
                end else begin
                    delay_counter <= delay_counter + 1;
                end
            end

            BURST: begin
                if (word_counter < BLOCK_WORDS) begin
                    DataIn <= memory[word_addr(base_address) + word_counter];
                    DataReady <= 1;
                    word_counter <= word_counter + 1;
                end else begin
                    state <= IDLE;
                end
            end
        endcase
    end
end

endmodule

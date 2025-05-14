// ucsbece154_imem.v - Fixed Baseline SDRAM Memory Model
// All changes marked with // NEW and old lines commented above

module ucsbece154_imem #(
    parameter TEXT_SIZE = 64,
    parameter BLOCK_WORDS = 4,          // words per burst (must match cache)
    parameter T0_DELAY = 40             // first word delay (cycles)
)(
    input wire clk,
    input wire reset,

    input wire ReadRequest,
    input wire [31:0] ReadAddress,

    output reg [31:0] DataIn,
    output reg DataReady
);

// NEW: Memory array to simulate SDRAM contents
reg [31:0] memory [0:TEXT_SIZE-1];

// NEW: FSM to handle SDRAM burst protocol
typedef enum logic [1:0] {
    IDLE,
    T0_WAIT,
    BURST_SEND
} state_t;
state_t state;

// NEW: Internal registers
reg [5:0] t0_counter;               // max T0_DELAY = 63
reg [1:0] burst_counter;           // for 4-word blocks
reg [31:0] base_address;           // aligned block base

// Address conversion helper
function [31:0] word_addr;
    input [31:0] addr;
    begin
        word_addr = addr >> 2; // convert byte address to word index
    end
endfunction

always @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        DataIn <= 0;
        DataReady <= 0;
        t0_counter <= 0;
        burst_counter <= 0;
    end else begin
        DataReady <= 0; // default: not ready unless asserted below
        case (state)
            IDLE: begin
                if (ReadRequest) begin
                    base_address <= {ReadAddress[31:BLOCK_WORDS + 2], {BLOCK_WORDS{1'b0}}}; // aligned base
                    t0_counter <= 0;
                    burst_counter <= 0;
                    state <= T0_WAIT;
                end
            end

            T0_WAIT: begin
                if (t0_counter == T0_DELAY) begin
                    DataIn <= memory[word_addr(base_address)];
                    DataReady <= 1;
                    burst_counter <= 1;
                    state <= BURST_SEND;
                end else begin
                    t0_counter <= t0_counter + 1;
                end
            end

            BURST_SEND: begin
                if (burst_counter < BLOCK_WORDS) begin
                    DataIn <= memory[word_addr(base_address) + burst_counter];
                    DataReady <= 1;
                    burst_counter <= burst_counter + 1;
                end else begin
                    state <= IDLE;
                end
            end
        endcase
    end
end

endmodule
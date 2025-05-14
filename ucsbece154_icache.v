// ucsbece154_icache.v - Pure Verilog 2001 Compliant Baseline ICache
// All changes marked with // NEW and old lines commented above

module ucsbece154_icache (
    Clk,
    Reset,
    ReadEnable,
    ReadAddress,
    Instruction,
    Ready,
    Busy,
    MemReadAddress,
    MemReadRequest,
    MemDataIn,
    MemDataReady
);

parameter NUM_SETS = 8;
parameter NUM_WAYS = 4;
parameter BLOCK_WORDS = 4;
parameter WORD_SIZE = 32;

input Clk;
input Reset;
input ReadEnable;
input [31:0] ReadAddress;
output reg [WORD_SIZE-1:0] Instruction;
output reg Ready;
output reg Busy;
output reg [31:0] MemReadAddress;
output reg MemReadRequest;
input [31:0] MemDataIn;
input MemDataReady;

// Address calculations
parameter WORD_OFFSET = 2;
parameter BLOCK_OFFSET = 2; // log2(BLOCK_WORDS)
parameter SET_OFFSET = 3;   // log2(NUM_SETS)
parameter OFFSET = WORD_OFFSET + BLOCK_OFFSET;
parameter NUM_TAG_BITS = 32 - SET_OFFSET - BLOCK_OFFSET - WORD_OFFSET;

// Cache structures
reg [0:0] valid [0:NUM_SETS-1][0:NUM_WAYS-1];
reg [NUM_TAG_BITS-1:0] tag_array [0:NUM_SETS-1][0:NUM_WAYS-1];
reg [31:0] data_array [0:NUM_SETS-1][0:NUM_WAYS-1][0:BLOCK_WORDS-1];

// Internal signals
reg [31:0] ReadAddress_reg;
reg [SET_OFFSET-1:0] set_idx;
reg [BLOCK_OFFSET-1:0] block_offset;
reg [NUM_TAG_BITS-1:0] tag;
reg [1:0] hit_way;
reg hit;
reg [31:0] block_buffer [0:BLOCK_WORDS-1];
reg [1:0] word_counter;
reg [1:0] replace_way;
reg [2:0] state;

parameter IDLE = 3'd0;
parameter MISS_WAIT = 3'd1;
parameter MEM_FILL = 3'd2;
parameter CACHE_WRITE = 3'd3;
parameter DONE = 3'd4;

// Hit detection logic
integer w, b;
always @(*) begin
    hit = 0;
    hit_way = 0;
    set_idx = ReadAddress[OFFSET +: SET_OFFSET];
    tag = ReadAddress[31 -: NUM_TAG_BITS];
    block_offset = ReadAddress[WORD_OFFSET +: BLOCK_OFFSET];
    for (w = 0; w < NUM_WAYS; w = w + 1) begin
        if (valid[set_idx][w] && tag_array[set_idx][w] == tag) begin
            hit = 1;
            hit_way = w[1:0];
        end
    end
end

always @(posedge Clk) begin
    if (Reset) begin
        state <= IDLE;
        Ready <= 0;
        Busy <= 0;
        MemReadRequest <= 0;
        word_counter <= 0;
        for (w = 0; w < NUM_WAYS; w = w + 1)
            for (b = 0; b < NUM_SETS; b = b + 1)
                valid[b][w] <= 0;
    end else begin
        Ready <= 0;
        case (state)
            IDLE: begin
                if (ReadEnable && !Busy) begin
                    if (hit) begin
                        ReadAddress_reg <= ReadAddress;
                        state <= DONE;
                    end else begin
                        replace_way <= $random % NUM_WAYS;
                        MemReadAddress <= {ReadAddress[31:OFFSET], {OFFSET{1'b0}}};
                        MemReadRequest <= 1;
                        word_counter <= 0;
                        Busy <= 1;
                        state <= MISS_WAIT;
                    end
                end
            end

            MISS_WAIT: begin
                if (MemDataReady) begin
                    block_buffer[0] <= MemDataIn;
                    word_counter <= 1;
                    state <= MEM_FILL;
                end
            end

            MEM_FILL: begin
                if (MemDataReady) begin
                    block_buffer[word_counter] <= MemDataIn;
                    word_counter <= word_counter + 1;
                    if (word_counter == BLOCK_WORDS-1) begin
                        MemReadRequest <= 0;
                        state <= CACHE_WRITE;
                    end
                end
            end

            CACHE_WRITE: begin
                valid[set_idx][replace_way] <= 1;
                tag_array[set_idx][replace_way] <= tag;
                for (w = 0; w < BLOCK_WORDS; w = w + 1)
                    data_array[set_idx][replace_way][w] <= block_buffer[w];
                state <= DONE;
            end

            DONE: begin
                if (hit)
                    Instruction <= data_array[set_idx][hit_way][block_offset];
                else
                    Instruction <= block_buffer[block_offset];
                Ready <= 1;
                Busy <= 0;
                state <= IDLE;
            end
        endcase
    end
end

endmodule

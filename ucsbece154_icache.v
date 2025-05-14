// ucsbece154_icache.v - Fixed Baseline ICache
// All changes marked with // NEW and old code commented out above

module ucsbece154_icache #(
    parameter NUM_SETS   = 8,
    parameter NUM_WAYS   = 4,
    parameter BLOCK_WORDS= 4,
    parameter WORD_SIZE  = 32
)(
    input                     Clk,
    input                     Reset,

    // core fetch interface
    input                     ReadEnable,
    input      [31:0]         ReadAddress,
    output reg [WORD_SIZE-1:0] Instruction,
    output reg                Ready,
    output reg                Busy,

    // SDRAM-controller interface
    output reg [31:0]         MemReadAddress,
    output reg                MemReadRequest,
    input      [31:0]         MemDataIn,
    input                     MemDataReady
);

localparam WORD_OFFSET   = 2;
localparam BLOCK_OFFSET  = $clog2(BLOCK_WORDS);
localparam SET_OFFSET    = $clog2(NUM_SETS);
localparam OFFSET        = WORD_OFFSET + BLOCK_OFFSET;
localparam NUM_TAG_BITS  = 32 - SET_OFFSET - BLOCK_OFFSET - WORD_OFFSET;

// Cache entry definition
typedef struct packed {
    logic                    valid;
    logic [NUM_TAG_BITS-1:0] tag;
    logic [31:0]             data [0:BLOCK_WORDS-1];
} cache_entry_t;

cache_entry_t cache [0:NUM_SETS-1][0:NUM_WAYS-1];

// NEW: FSM states
typedef enum logic [2:0] {
    IDLE,
    MISS_WAIT,
    MEM_FILL,
    CACHE_WRITE,
    DONE
} state_t;
state_t state;

// NEW: Internal registers
reg [31:0] ReadAddress_reg;
reg [NUM_TAG_BITS-1:0] tag;
reg [SET_OFFSET-1:0] set_idx;
reg [BLOCK_OFFSET-1:0] block_offset;
reg [1:0] hit_way;
reg hit;
reg [WORD_SIZE-1:0] block_buffer [0:BLOCK_WORDS-1];
reg [1:0] word_counter;
reg [1:0] replace_way;

// Decode address fields
always @(*) begin
    tag          = ReadAddress[31 -: NUM_TAG_BITS];
    set_idx      = ReadAddress[OFFSET +: SET_OFFSET];
    block_offset = ReadAddress[WORD_OFFSET +: BLOCK_OFFSET];
end

// Hit detection
integer w;
always @(*) begin
    hit = 0;
    hit_way = 0;
    for (w = 0; w < NUM_WAYS; w = w + 1) begin
        if (cache[set_idx][w].valid && cache[set_idx][w].tag == tag)
            hit = 1;
            hit_way = w;
    end
end

// FSM
always @(posedge Clk) begin
    if (Reset) begin
        state <= IDLE;
        Ready <= 0;
        Busy <= 0;
        MemReadRequest <= 0;
        word_counter <= 0;
        // Invalidate all cache entries
        for (int s = 0; s < NUM_SETS; s++)
            for (int w = 0; w < NUM_WAYS; w++)
                cache[s][w].valid <= 0;
    end else begin
        case (state)
            IDLE: begin
                Ready <= 0;
                if (ReadEnable && !Busy) begin
                    if (hit) begin
                        // Cache hit: output on next cycle
                        ReadAddress_reg <= ReadAddress; // NEW
                        state <= DONE;
                    end else begin
                        // Cache miss: start memory request
                        replace_way <= $random % NUM_WAYS; // NEW
                        MemReadAddress <= {ReadAddress[31:BLOCK_OFFSET << 1], {BLOCK_OFFSET{1'b0}}}; // align addr
                        MemReadRequest <= 1;
                        word_counter <= 0;
                        state <= MISS_WAIT;
                        Busy <= 1;
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
                cache[set_idx][replace_way].valid <= 1;
                cache[set_idx][replace_way].tag <= tag;
                for (int i = 0; i < BLOCK_WORDS; i++)
                    cache[set_idx][replace_way].data[i] <= block_buffer[i];
                state <= DONE;
            end

            DONE: begin
                Instruction <= cache[set_idx][hit ? hit_way : replace_way].data[block_offset];
                Ready <= 1;
                Busy <= 0;
                state <= IDLE;
            end
        endcase
    end
end

endmodule

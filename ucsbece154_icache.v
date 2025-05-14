module ucsbece154b_icache #(
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
    output reg [WORD_SIZE-1:0]Instruction,
    output reg                Ready,
    output reg                Busy,

    // SDRAM-controller interface
    output reg [31:0]         MemReadAddress,
    output reg                MemReadRequest,
    input      [31:0]         MemDataIn,
    input                     MemDataReady
);



localparam BLOCK_OFFSET = $clog2(BLOCK_WORDS); // 2 bits for word offset
localparam WORD_OFFSET = 2; // 2 bits for word offset
localparam NUM_TAG_BITS = 32 - $clog2(NUM_SETS) - $clog2(BLOCK_WORDS) - 2; // 32 - set bits - block bits - 2 bits for word offset
localparam NUM_BLOCK_BITS = $clog2(BLOCK_WORDS);


wire set_index = ReadAddress[$clog2(NUM_SETS)+BLOCK_OFFSET+WORD_OFFSET:BLOCK_OFFSET+WORD_OFFSET]; // get set index from read address

// implementation of the cache here
// Create table for cache:
// | Valid Bit (1 bit) | Tag (25 bits - ReadAddress[31:7]) | Data (128 bits - 4 words) |    --->  x4 for each way; this is one entry for each set (8 total)
// to index into cache table, obtain set index from read address

// 1 per way per set
reg [NUM_TAG_BITS-1:0] tags [NUM_SETS-1:0][NUM_WAYS-1:0];
reg [NUM_WAYS-1:0] valid_bits [NUM_SETS-1:0][NUM_WAYS-1:0];

// 4 words per way per set
reg [WORD_SIZE-1:0] words [NUM_SETS-1:0][NUM_WAYS-1:0][BLOCK_WORDS-1:0];

reg write_way;

// READY SIGNAL
always @ (*) begin
    if (Ready) begin
        // ready to read from cache
        Instruction <= words[set_index][write_way][ReadAddress[BLOCK_OFFSET-1:0]];
    end else begin
        // not ready to read from cache
        Instruction <= 0;
    end
end

integer i, j, k;
always @ (posedge Clk) begin
  // clear all fields in cache
    if (Reset) begin
        for (i = 0; i < NUM_SETS; i = i + 1) begin
            for (j = 0; j < NUM_WAYS; j = j + 1) begin
                valid_bits[i][j] <= 0;
                tags[i][j] <= 0;
                for (k = 0; k < BLOCK_WORDS; k = k + 1) begin
                    words[i][j][k] <= 0;
                end
            end
        end
        Instruction <= 0;
        Ready <= 0;
        Busy <= 0;
        MemReadRequest <= 0;
        MemReadAddress <= 0;
    end
end

// READ

integer i_ways;
reg hit;
always @ (posedge Clk) begin
    // TODO check on setup time for when readenable is supplied
    hit = 0;
    if (!Busy && ReadEnable) begin
        // check if readaddress is in cache aka "valid"
        for (i_ways = 0; i_ways < NUM_WAYS; i_ways = i_ways + 1) begin
            if (valid_bits[set_index][i_ways] && (tags[set_index][i_ways] == ReadAddress[31:$clog2(NUM_SETS)+BLOCK_OFFSET+WORD_OFFSET+1])) begin
                // hit - read from cache
                write_way <= i_ways;
                Ready <= 1;
                Busy <= 0;
                hit = 1;
            end
        end
    end
    // if not in cache, need to read from memory and write to cache
    if (!hit) begin
        // set up memory read request
        MemReadAddress <= ReadAddress;
        MemReadRequest <= 1;
        Busy <= 1;
        Ready <= 0;
    end 
end


// WRITE
reg found_empty_way = 0;
integer write_way_index;
integer word_count;
// there was a miss - need to write to cache from memory
always @ (posedge Clk) begin
    if (MemReadRequest && MemDataReady) begin
        // write to cache
        for (write_way_index = 0; write_way_index < NUM_WAYS; write_way_index = write_way_index + 1) begin
            if (!valid_bits[set_index][write_way_index]) begin
                // found empty way - write to it
                found_empty_way = 1;
                write_way <= write_way_index;
            end
        end

        // if all ways are full, evict one way (random)
        if (!found_empty_way) begin
            // evict a random way
            write_way <= $urandom_range(0, NUM_WAYS-1);
        end

        // read data from memory and write to cache
        words[set_index][write_way][word_count] <= MemDataIn;
        valid_bits[set_index][write_way] <= 1;
        tags[set_index][write_way] <= ReadAddress[31:$clog2(NUM_SETS)+BLOCK_OFFSET+WORD_OFFSET+1];

        if (word_count < BLOCK_WORDS-1) begin
            word_count <= word_count + 1;
        end else begin
            // reset word count
            word_count <= 0;
            found_empty_way = 0;
            MemReadRequest <= 0;
            Busy <= 0;
            Ready <= 1;
        end
    end
end

endmodule
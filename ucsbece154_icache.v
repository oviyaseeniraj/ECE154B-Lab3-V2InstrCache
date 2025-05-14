// ucsbece154b_icache.v
// All Rights Reserved
// Copyright (c) 2024 UCSB ECE
// Distribution Prohibited

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

localparam BLOCK_OFFSET = $clog2(BLOCK_WORDS);
localparam WORD_OFFSET = 2;
localparam NUM_TAG_BITS = 32 - $clog2(NUM_SETS) - BLOCK_OFFSET - WORD_OFFSET;
localparam NUM_BLOCK_BITS = $clog2(BLOCK_WORDS);

wire [$clog2(NUM_SETS)-1:0] set_index;
assign set_index = ReadAddress[$clog2(NUM_SETS)+BLOCK_OFFSET+WORD_OFFSET-1:BLOCK_OFFSET+WORD_OFFSET];

reg [NUM_TAG_BITS-1:0] tags [NUM_SETS-1:0][NUM_WAYS-1:0];
reg                    valid_bits [NUM_SETS-1:0][NUM_WAYS-1:0];
reg [WORD_SIZE-1:0]    words [NUM_SETS-1:0][NUM_WAYS-1:0][BLOCK_WORDS-1:0];

reg [$clog2(NUM_WAYS)-1:0] write_way;
reg [$clog2(NUM_WAYS)-1:0] hit_way; 
reg [1:0] burst_word_index;
reg pending_refill;
reg refilled_this_cycle; // NEW

integer i, j, k;
always @ (posedge Clk) begin
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
        burst_word_index <= 0;
        hit_way <= 0;
        pending_refill <= 0;
        refilled_this_cycle <= 0; // NEW
    end else begin
        Ready <= 0;

        if (!Busy && ReadEnable && !pending_refill) begin
            for (i = 0; i < NUM_WAYS; i = i + 1) begin
                if (valid_bits[set_index][i] && (tags[set_index][i] == ReadAddress[31:$clog2(NUM_SETS)+BLOCK_OFFSET+WORD_OFFSET])) begin
                    hit_way <= i;
                    Ready <= 1;
                    Instruction <= words[set_index][i][ReadAddress[BLOCK_OFFSET-1:0]];
                end
            end
        end else if (pending_refill && refilled_this_cycle) begin // NEW
            Ready <= 1;
            Instruction <= words[set_index][write_way][ReadAddress[BLOCK_OFFSET-1:0]];
            pending_refill <= 0;
            refilled_this_cycle <= 0;
        end
    end
end

integer i_ways;
reg hit;
always @ (posedge Clk) begin
    hit = 0;
    if (!Busy && ReadEnable) begin
        for (i_ways = 0; i_ways < NUM_WAYS; i_ways = i_ways + 1) begin
            if (valid_bits[set_index][i_ways] && (tags[set_index][i_ways] == ReadAddress[31:$clog2(NUM_SETS)+BLOCK_OFFSET+WORD_OFFSET])) begin
                hit = 1;
            end
        end
        if (!hit) begin
            MemReadAddress <= {ReadAddress[31:2], 2'b00};
            MemReadRequest <= 1;
            Busy <= 1;
            burst_word_index <= 0;
        end
    end
end

reg found_empty_way;
integer write_way_index;
always @ (posedge Clk) begin
    if (MemReadRequest && MemDataReady) begin
        words[set_index][write_way][burst_word_index] <= MemDataIn;
        burst_word_index <= burst_word_index + 1;

        if (burst_word_index == BLOCK_WORDS - 1) begin
            found_empty_way = 0;
            for (write_way_index = 0; write_way_index < NUM_WAYS; write_way_index = write_way_index + 1) begin
                if (!valid_bits[set_index][write_way_index]) begin
                    found_empty_way = 1;
                    write_way <= write_way_index;
                end
            end
            if (!found_empty_way) begin
                write_way <= $urandom_range(0, NUM_WAYS-1);
            end
            valid_bits[set_index][write_way] <= 1;
            tags[set_index][write_way] <= ReadAddress[31:$clog2(NUM_SETS)+BLOCK_OFFSET+WORD_OFFSET];
            MemReadRequest <= 0;
            Busy <= 0;
            pending_refill <= 1;
            refilled_this_cycle <= 1; // NEW
        end else begin
            MemReadAddress <= MemReadAddress + 4;
        end
    end
end

endmodule

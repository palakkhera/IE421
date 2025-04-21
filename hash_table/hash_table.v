/*
+-----------------------+
|     hash_table.v      |
+-----------------------+
| - buckets[0..N-1]     |  -->  index = hash(key)
|                       |        ↓
| - entry_pool[0..M-1]  |  -> linked list:
|                       |     [entry0] -> [entry5] -> ...
| - freelist management |
+-----------------------+
*/

// Chained hash table with separate chaining and simple freelist allocator
module hash_table #(
    parameter KEY_WIDTH    = 32, // assuming 32 bit orderId
    parameter VALUE_WIDTH  = 64, // sizeof(void*) is 8 bytes
    parameter TABLE_SIZE   = 8192, // number of buckets
    parameter INDEX_WIDTH  = $clog2(TABLE_SIZE),
    parameter POOL_SIZE    = 131072 // max number of hash table entries, must be less than 2^32
)(
    input                        clk,
    input                        rst,

    input      [KEY_WIDTH-1:0]   key,
    input      [VALUE_WIDTH-1:0] value_in,
    input                        insert,
    input                        lookup,
    input                        erase,
    output reg [VALUE_WIDTH-1:0] value_out,
    output reg                   success,
    output reg [1:0]             state
);
    localparam IDLE = 0, SEARCH = 1, DONE = 2;
    localparam NULL = 32'hFFFF_FFFF;

    // Hash table bucket array (head pointer for each bucket)
    reg [31:0] buckets [0:TABLE_SIZE-1];

    // Entry pool: flat memory for entries {key, value, next}
    reg [KEY_WIDTH-1:0]    pool_key   [0:POOL_SIZE-1];
    reg [VALUE_WIDTH-1:0]  pool_value [0:POOL_SIZE-1];
    reg [31:0]             pool_next  [0:POOL_SIZE-1];

    // Freelist for entry allocation
    reg [31:0] freelist_head;
    reg [31:0] freelist_next [0:POOL_SIZE-1];

    // Compute index
    wire [INDEX_WIDTH-1:0] index;
    assign index = key[INDEX_WIDTH-1:0];

    reg [31:0] curr;
    reg [31:0] prev;

    // Initialize buckets and freelist
    integer i;
    initial begin
        for (i = 0; i < TABLE_SIZE; i = i + 1) buckets[i] = NULL;
        for (i = 0; i < POOL_SIZE; i = i + 1) freelist_next[i] = i + 1;
        freelist_next[POOL_SIZE-1] = NULL;
        freelist_head = 1; // 0 should work here but there is a bug
    end

    always @(posedge clk) begin
        if (rst) begin 
            success   <= 0;
            value_out <= 0;
            state     <= IDLE;
        end else begin
            success   <= 0;
            value_out <= 0;

            case (state)
                IDLE: begin
                    if (insert) begin
                        if (freelist_head != NULL) begin
                            curr <= freelist_head;
                            freelist_head <= freelist_next[curr];

                            pool_key[curr]   <= key;
                            pool_value[curr] <= value_in;
                            pool_next[curr]  <= buckets[index];

                            buckets[index] <= curr;

                            $display("after insert\nbuckets[index]");
                            $display(buckets[index]);
                            $display("curr");
                            $display(curr);
                            $display("freelist_head");
                            $display(freelist_head);
                            $display("freelist_next[curr]");
                            $display(freelist_next[curr]);
                            $display("pool_next[curr]");
                            $display(pool_next[curr]);
                            $display("index");
                            $display(index);
                            $display("----------");

                            value_out <= value_in;
                            success   <= 1;
                            state     <= DONE;
                        end else begin
                            success <= 0;
                            state   <= DONE;
                        end
                    end else if (lookup || erase) begin
                        curr <= buckets[index];
                        prev <= NULL;
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    
                    $display("----\n", curr, pool_next[curr], "\n----");
                    
                    if (curr != NULL) begin
                        if (pool_key[curr] == key) begin
                            value_out <= pool_value[curr];
                            success   <= 1;
                            if (erase) begin
                                // Remove from chain
                                if (prev == NULL) begin
                                    $display("removing " , curr , " to " , pool_next[curr], "(prev=null)");
                                    buckets[index] <= pool_next[curr];
                                end else begin
                                    $display("removing " , curr , " to " , pool_next[curr]);
                                    pool_next[prev] <= pool_next[curr];
                                end
                                // Add to freelist
                                freelist_next[curr] <= freelist_head;
                                freelist_head <= curr;
                            end
                            state <= DONE;
                        end else begin
                            prev <= curr;
                            curr <= pool_next[curr];
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

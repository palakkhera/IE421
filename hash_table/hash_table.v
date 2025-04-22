/*
-------------------------------------------------------------------------------
  Verilog Hash Table with Separate Chaining and Freelist-Based Allocation
-------------------------------------------------------------------------------

  This module implements a parameterized hash table with separate chaining
  for collision resolution. Each bucket contains a linked list of entries
  stored in a flat memory pool. A simple freelist allocator is used to
  manage dynamic allocation and deallocation of entries in the pool.

  Features:
    - Fixed-size hash table with TABLE_SIZE buckets
    - Separate chaining via singly linked lists
    - Custom key and value widths (KEY_WIDTH, VALUE_WIDTH)
    - Entry pool of size POOL_SIZE with explicit memory reuse
    - LRU-style freelist management for reusing deleted entries
    - Finite state machine (FSM) to process insert, lookup, and erase ops

  Interface:
    Inputs:
      clk       - clock signal
      rst       - synchronous reset
      key       - input key
      value_in  - value associated with key (for insert)
      op        - operation request signal (0 == noop, 1 == insert, 2 == lookup, 3 == erase)

    Outputs:
      value_out - value returned during lookup or erase
      success   - operation success flag
      state     - current FSM state (IDLE, SEARCHING, INSERTING, DONE)

  Notes:
    - Keys are hashed using the low bits of the key.
    - All operations are pipelined and handled across multiple clock cycles.
    - User must wait for state == DONE before issuing a new request.
-------------------------------------------------------------------------------
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
    input  reg [1:0]             op,
    output reg [VALUE_WIDTH-1:0] value_out,
    output reg                   success,
    output reg [1:0]             state
);
    // Edit these in HashTable.hpp too if any changes are needed.
    localparam IDLE = 0, SEARCHING = 1, INSERTING = 2, DONE = 3; // state
    localparam NOOP = 0, INSERT = 1, LOOKUP = 2, ERASE = 3; // operation

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
        freelist_head = 0;
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
                    curr <= buckets[index];
                    prev <= NULL;
                    if (op == NOOP) begin
                        state <= DONE;
                    end else begin
                        state <= SEARCHING;
                    end;
                end // IDLE

                SEARCHING: begin
                    if (curr != NULL) begin
                        if (pool_key[curr] == key) begin
                            case (op)
                                ERASE: begin
                                    // Remove from chain
                                    if (prev == NULL) begin
                                        buckets[index] <= pool_next[curr];
                                    end else begin
                                        pool_next[prev] <= pool_next[curr];
                                    end
                                    // Add to freelist
                                    freelist_next[curr] <= freelist_head;
                                    freelist_head <= curr; 
                                    value_out <= pool_value[curr];
                                    state     <= DONE;
                                    success   <= 1;
                                end // ERASE
                                INSERT: begin
                                    pool_value[curr] <= value_in;
                                    value_out <= pool_value[curr];
                                    state     <= DONE;
                                    success   <= 1;
                                end // INSERT
                                LOOKUP: begin
                                    value_out <= pool_value[curr];
                                    state     <= DONE;
                                    success   <= 1;
                                end // LOOKUP
                            endcase;
                        end else begin
                            prev <= curr;
                            curr <= pool_next[curr];
                        end
                    end else begin
                        if (op == INSERT) begin
                            state <= INSERTING;
                        end else begin
                            state <= DONE; 
                        end
                    end
                end // SEARCHING

                INSERTING: begin
                    if (freelist_head != NULL) begin
                        // curr <= freelist_head;
                        freelist_head <= freelist_next[freelist_head];

                        pool_key[freelist_head]   <= key;
                        pool_value[freelist_head] <= value_in;
                        pool_next[freelist_head]  <= buckets[index];

                        buckets[index] <= freelist_head;

                        value_out <= value_in;
                        success   <= 1;
                        state     <= DONE;
                    end else begin
                        success <= 0;
                        state   <= DONE;
                    end
                end // INSERTING

                DONE: begin
                    state <= IDLE;
                end // DONE
            endcase
        end
    end
endmodule

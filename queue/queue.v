// -----------------------------------------------------------------------------
// queue.v
// -----------------------------------------------------------------------------
// A simple queue data structure implemented in Verilog.
//
// Supports the following operations:
// - PUSH:   Add a new value at the end of the queue.
// - POP:    Remove and output the first valid value from the queue.
// - PEEK:   Output the first valid value without removing it.
// - REMOVE: Remove an element at a specified index.
// - MODIFY: Modify the value at a specified index.
//
// Internally, the queue:
// - Stores entries in a fixed-size array of DATA_SIZE width.
// - Maintains a 'valid' bit per entry to track active/inactive slots.
// - Supports lazy deletion (removed elements are marked invalid and skipped).
//
// Module Parameters:
// - DATA_SIZE:      Width of each data element (default 64 bits).
// - QUEUE_CAPACITY: Maximum number of elements (default 65536).
// - INDEX_WIDTH:    Width of indices to address the queue (calculated from capacity).
//
// Inputs:
// - clk:        Clock signal.
// - rst:        Reset signal.
// - value_in:   Value to push or modify.
// - op_index:   Index for REMOVE or MODIFY operations.
// - op:         Operation code (NOOP, PUSH, POP, PEEK, REMOVE, MODIFY).
//
// Outputs:
// - value_out:  Output value (for PEEK or POP).
// - success:    High if the operation succeeded.
// - state:      Current internal state (IDLE, BUSY, FLUSHING, DONE).
//
// Notes:
// - On reset, the queue is cleared.
// - Popping and peeking skip over invalid entries automatically.
// - Physical data movement is avoided for performance; entries are only marked valid/invalid.
// - Modifying any inputs or outputs before state == DONE is undefined behavior.
//
// -----------------------------------------------------------------------------

module queue #(
    parameter DATA_SIZE      = 64,
    parameter QUEUE_CAPACITY = 65536, // Max number of elements in queue (including elements marked as removed but have not yet been cleared)
                                      // Change this in Queue.hpp if modified
    parameter INDEX_WIDTH    = $clog2(QUEUE_CAPACITY)
)(
    input                        clk,
    input                        rst,
    input  reg [DATA_SIZE-1:0]   value_in,
    input  reg [INDEX_WIDTH-1:0] index,
    input  reg [2:0]             op,

    output reg [DATA_SIZE-1:0]   value_out,
    output reg                   success,
    output reg [1:0]             state,
    output reg [31:0]            size
);
    // Edit these in Queue.hpp too if any changes are needed.
    localparam IDLE = 0, BUSY = 1, FLUSHING = 2, DONE = 3; // state
    localparam NOOP = 0, PUSH = 1, POP = 2, PEEK = 3, REMOVE = 4, MODIFY = 5; // operation

    reg [INDEX_WIDTH-1:0] head_index; // index of first valid entry, or 0 if empty
    reg [INDEX_WIDTH-1:0] tail_index; // index after last valid entry, or 0 if empty

    reg [DATA_SIZE-1:0] data  [0:QUEUE_CAPACITY-1];

    // Denotes if entry is actually in the queue (and not removed)
    // Only defined for indices between head_index and tail_index (wrapping around if needed)
    // Otherwise, resetting would be expensive
    reg                 valid [0:QUEUE_CAPACITY-1];

    // For debugging
    integer i;
    initial begin
        for (i = 0; i < QUEUE_CAPACITY; i = i + 1) valid[i] = 0;
    end

    always @(posedge clk) begin
        if (rst) begin 
            success    <= 0;
            value_out  <= 0;
            head_index <= 0;
            tail_index <= 0;
            size       <= 0;
            state      <= DONE;
        end else begin
            case (state)
                IDLE: begin
                    success <= 0;
                    value_out <= 0;
                    if (op != NOOP) begin
                        state <= BUSY;
                    end else begin
                        state <= DONE;
                    end
                end

                BUSY: begin
                    case (op)
                        PUSH: begin
                            if (size > 0) begin
                                if (head_index == tail_index) begin
                                    // No room for additional entry
                                    success <= 0;
                                    state <= DONE;
                                end else begin
                                    data[tail_index] <= value_in;
                                    valid[tail_index] <= 1;
                                    tail_index <= tail_index + 1;
                                    size <= size + 1;
                                    value_out <= value_in;
                                    success <= 1;
                                    state <= DONE;
                                end
                            end else begin
                                data[tail_index] <= value_in;
                                valid[tail_index] <= 1;
                                head_index <= 0;
                                tail_index <= 1;
                                size <= 1;
                                value_out <= value_in;
                                success <= 1;
                                state <= DONE;
                            end
                        end

                        PEEK: begin
                            if (size > 0) begin
                                success <= 1;
                                value_out <= data[head_index];
                                state <= DONE;
                            end else begin
                                success <= 0;
                                state <= DONE;
                            end
                        end

                        POP: begin
                            if (size > 0) begin
                                value_out <= data[head_index];
                                // valid[head_index] <= 0;
                                head_index <= head_index + 1;
                                size <= size - 1;
                                success <= 1;
                                state <= FLUSHING;
                            end else begin
                                success <= 0;
                                state <= DONE;
                            end
                        end

                        REMOVE: begin
                            // do error checking plus other stuff, decrement size, etc.
                            valid[index] <= 0;
                            state <= DONE;
                        end

                        MODIFY: begin
                            state <= DONE;
                        end
                    endcase
                end

                FLUSHING: begin
                    if (size > 0 && !valid[head_index]) begin
                        head_index <= head_index + 1;
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

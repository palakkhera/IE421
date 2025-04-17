module queue #(
    parameter DATA_SIZE = 32,
    parameter FIFO_SIZE = 1024,//MUST BE POWER OF 2!!;
    parameter PTR_WIDTH = $clog2(FIFO_SIZE),
    parameter SCAN_SIZE = 16, //MUST BE POWER OF 2!!;
    parameter SCAN_WIDTH = $clog2(SCAN_SIZE)
)(
    input logic                     clk,
    input logic                     reset,

    input logic                     push_flag,
    input logic [DATA_SIZE-1:0]     push_data,

    input logic                     pop_flag,
    output logic [DATA_SIZE-1:0]    pop_data,

    input logic                     remove_flag,
    input logic [PTR_WIDTH-1:0]     remove_index,

    output logic                    full,
    output logic                    empty,
    output logic [PTR_WIDTH:0]      size,
    output logic                    error_reg,
    output logic                    error_rem, //
    output logic                    error_time //Not finished scanning for next head yet!
);

    logic [DATA_SIZE-1:0]       memory[0:FIFO_SIZE-1];
    logic                       valid[0:FIFO_SIZE-1];

    logic [PTR_WIDTH-1:0]       head;
    logic [PTR_WIDTH-1:0]       tail;
    logic [PTR_WIDTH:0]         counter;
    logic [PTR_WIDTH:0]         real_counter;
    logic                       error_t;
    logic                       error_r;
    logic                       error_g;

    

    logic [SCAN_SIZE-1: 0]      chunk;
    logic [SCAN_WIDTH: 0]       offset;
    logic                       is_pop;
    logic                       is_push;
    logic                       is_remove;
    logic [PTR_WIDTH-1:0]       head_next;
    logic [PTR_WIDTH-1:0]       tail_next;
    logic [PTR_WIDTH:0]         real_counter_next;
    logic [PTR_WIDTH:0]         available;

    function automatic logic [SCAN_WIDTH:0] priority16(input logic [SCAN_SIZE-1:0] chunk);
        for (int i = 0; i < SCAN_SIZE; i++) begin
            if (chunk[i]) return i;
        end
        return SCAN_SIZE;
    endfunction

    always_comb begin //pop; All the modulos are ignored because of the "truncating" feature. Careful when editing!
        is_pop = (pop_flag && real_counter > 0) ? 1 : 0;
        head_next = head + is_pop;
        for (int i = 0; i < SCAN_SIZE; i++) begin
            chunk[i] = valid[(head_next + i) & (FIFO_SIZE - 1)];
        end
        offset = priority16(chunk);
        available = {1'b0, tail} - {1'b0, head_next};
        if (offset > available) begin
            offset = available;
        end
        head_next = head_next + offset;
    end

    always_comb begin //push & remove;
        is_push = (push_flag && counter < FIFO_SIZE) ? 1 : 0;
        tail_next = tail + is_push;

        is_remove = (remove_flag && valid[remove_index]) ? 1 : 0;
        real_counter_next = real_counter + is_push - is_pop - is_remove; //It should be undefined behavior to have both is_pop && is_remove = 1;
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            head            <= 0;
            tail            <= 0;
            counter         <= 0;
            real_counter    <= 0;
            error_g         <= 0;
            error_r         <= 0;
            error_t         <= 0;
            // for (int i = 0; i < FIFO_SIZE; i++) begin
            //     valid[i]    <= 0;
            //     memory[i]   <= 0;
            // end (Maybe reset the memory when the queue is recycled?)
        end else begin
            if (push_flag && (counter < FIFO_SIZE)) begin 
                memory[tail]    <= push_data;
                valid[tail]     <= 1;
            end
            if (pop_flag && real_counter != 0) begin
                if (!valid[head]) begin
                    error_t         <= 1;
                end else begin
                    valid[head]     <= 0;
                    error_t         <= 0;
                end
            end else begin
                error_t             <= 0;
            end

            if ((push_flag && (counter == FIFO_SIZE)) || (pop_flag && (real_counter == 0))) begin
                error_g     <= 1;
            end else begin
                error_g     <= 0;
            end

            head            <= head_next;
            tail            <= tail_next;
            counter         <= {1'b0, tail} - {1'b0, head}; 
            real_counter    <= real_counter_next;  

            if (remove_flag) begin
                if (pop_flag) begin
                    error_r                 <= 1; //Remove & pop is not allowed!
                end else if (valid[remove_index]) begin
                    valid[remove_index]     <= 0;
                    error_r                 <= 0;
                end else begin 
                    error_r                 <= 1;
                end
            end else begin
                error_r                     <= 0;    
            end
        end

    end

    assign pop_data = valid[head] ? memory[head] : '0; //Need to check error_time first! Don't assume this is correct!

    assign empty        = (real_counter == 0);
    assign full         = (counter == FIFO_SIZE);
    assign size         = real_counter; // This is the real size!
    assign error_reg    = error_g;
    assign error_rem    = error_r;
    assign error_time   = error_t;
endmodule
    
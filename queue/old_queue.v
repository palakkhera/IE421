module queue #(
    parameter DATA_SIZE = 64,
    parameter FIFO_SIZE = 64,//MUST BE POWER OF 2!!;
    parameter PTR_WIDTH = $clog2(FIFO_SIZE),
    parameter SCAN_SIZE = 16, //MUST BE POWER OF 2!!;
    parameter SCAN_WIDTH = $clog2(SCAN_SIZE)
)(
    input logic                     clk,
    input logic                     reset,

    input logic [2:0]               op_flag, // 000=idle, 100=push, 101=pop, 110=remove, 111=modify
    input logic [PTR_WIDTH-1:0]     op_index,
    input logic [DATA_SIZE-1:0]     op_data,

    output logic [DATA_SIZE-1:0]    pop_data,

    output logic                    full,
    output logic                    empty,
    output logic [PTR_WIDTH:0]      size,
    output logic                    error_reg, // “global” push/pop overflow/underflow
    output logic                    error_rem, // remove/modify invalid
    output logic                    error_time // Not finished scanning for next head yet!
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
    logic                       is_modify;

    logic [PTR_WIDTH-1:0]       head_next;
    logic [PTR_WIDTH-1:0]       tail_next;
    logic [PTR_WIDTH:0]         real_counter_next;
    logic [PTR_WIDTH:0]         available;

    function automatic logic [SCAN_WIDTH:0] priority16(input logic [SCAN_SIZE-1:0] c);
        for (int i = 0; i < SCAN_SIZE; i++) begin
            if (c[i]) return i;
        end
        return SCAN_SIZE;
    endfunction

    always_comb begin //All the modulos are ignored because of the "truncating" feature. Careful when editing!
        is_push     = (op_flag == 2'b00) && (counter < FIFO_SIZE);
        is_pop      = (op_flag == 2'b01) && (real_counter > 0);
        is_remove   = (op_flag == 2'b10) && (valid[op_index]);
        is_modify   = (op_flag == 2'b11) && (valid[op_index]);
        
        tail_next   = tail + is_push;
        head_next   = head + is_pop;

        for (int i = 0; i < SCAN_SIZE; i++) begin
            chunk[i] = valid[(head_next + i) & (FIFO_SIZE - 1)];
        end
        offset = priority16(chunk);

        available = {1'b0, tail} - {1'b0, head_next};
        if (offset > available) begin
            offset = available;
        end

        head_next = head_next + offset;

        real_counter_next = real_counter + is_push - is_pop - is_remove; 
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
            // --- push ---
            if (op_flag == 2'b00) begin 
                if (counter < FIFO_SIZE) begin
                    memory[tail]    <= op_data;
                    valid[tail]     <= 1;
                    error_g         <= 0;
                end else begin 
                    error_g         <= 1;
                end
            end

            // --- pop ---
            if (op_flag == 2'b01) begin
                if (real_counter > 0) begin
                    if (!valid[head]) begin
                        error_t     <= 1;
                    end else begin
                        valid[head] <= 0;
                        error_t     <= 0;
                    end
                end else begin
                    error_g         <= 1; 
                end
            end
            
            // --- remove & modify ---
            if (op_flag == 2'b10 || op_flag == 2'b11) begin
                if (valid[op_index]) begin
                    if (op_flag == 2'b10) begin
                        valid[op_index]     <= 0;
                    end else begin
                        memory[op_index]    <= op_data;
                    end
                    error_r                 <= 0;
                end else begin 
                    error_r                 <= 1;
                end
            end else begin
                error_r                     <= 0;    
            end

            head            <= head_next;
            tail            <= tail_next;
            counter         <= {1'b0, tail} - {1'b0, head}; 
            real_counter    <= real_counter_next;  
        end
    end

    assign pop_data     = (op_flag == 2'b01 && valid[head]) ? memory[head] : '0; //Need to check error_time first! Don't assume this is correct!

    assign empty        = (real_counter == 0);
    assign full         = (counter == FIFO_SIZE);
    assign size         = real_counter; // This is the real size!
    assign error_reg    = error_g;
    assign error_rem    = error_r;
    assign error_time   = error_t;
endmodule

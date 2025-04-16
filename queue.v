module queue #(
    parameter DATA_SIZE = 32,
    parameter FIFO_SIZE = 1024,
    parameter PTR_WIDTH = $clog2(FIFO_SIZE)
)(
    input logic                     clk,
    input logic                     reset,

    input logic                     push_flag,
    input logic [DATA_SIZE-1:0]     push_data,

    input logic                     pop_flag,
    output logic [DATA_SIZE-1:0]    pop_data,

    output logic                    full,
    output logic                    empty,
    output logic [PTR_WIDTH-1:0]    size,
    output logic                    error
);

    logic [DATA_SIZE-1:0] memory[0:FIFO_SIZE-1];

    logic [PTR_WIDTH-1:0] head;
    logic [PTR_WIDTH-1:0] tail;
    logic [PTR_WIDTH:0] counter;
    logic               error_t;

    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            head    <= 0;
            tail    <= 0;
            counter <= 0;
            error_t <= 0;
        end else begin

            if (push_flag && pop_flag && (counter < FIFO_SIZE) && (counter > 0)) begin 
                memory[head]    <= push_data;
                head            <= (head == FIFO_SIZE - 1) ? 0 : head + 1;
                tail            <= (tail == FIFO_SIZE - 1) ? 0 : tail + 1;  
                error_t         <= 0;
            end else if (!push_flag && pop_flag && (counter > 0)) begin 
                tail            <= (tail == FIFO_SIZE - 1) ? 0 : tail + 1;
                counter         <= counter - 1;    
                error_t         <= 0;
            end else if (push_flag && !pop_flag && (counter < FIFO_SIZE)) begin
                memory[head]    <= push_data;
                head            <= (head == FIFO_SIZE - 1) ? 0 : head + 1;
                counter         <= counter + 1;   
                error_t         <= 0;     
            end else if (push_flag || pop_flag) begin
                error_t         <= 1;
            end else begin 
                error_t         <= 0;
            end
        end

    end

    assign pop_data = memory[tail];

    assign empty    = (counter == 0);
    assign full     = (counter == FIFO_SIZE);
    assign size     = counter;
    assign error    = error_t;
endmodule
    
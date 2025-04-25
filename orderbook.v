module orderbook #(
	parameter DATA_SIZE    = 64,
	parameter FIFO_SIZE    = 64,
	parameter PTR_WIDTH    = $clog2(FIFO_SIZE),
	parameter PRICE_LEVELS = 256,
	parameter PRICE_WIDTH  = $clog2(PRICE_LEVELS),
	parameter MAX_QUEUES   = 1024,
	parameter PTR_QUEUE    = $clog2(MAX_QUEUES),
)(
	input  logic                   clk,
	input  logic                   reset,

	// 00=add,01=match,10=remove,11=modify
	input  logic [1:0]             op_flag,
	input  logic                   side,   // 0=bid,1=ask
	input  logic [PRICE_WIDTH-1:0] price,
	input  logic [PTR_QUEUE-1:0]   op_q_index,
	input  logic [PTR_WIDTH-1:0]   op_index,
	input  logic [DATA_SIZE-1:0]   op_data,

	// match pops one per cycle
	output logic [DATA_SIZE-1:0]   ob_pop_data,
	output logic                   error_match // matching in progress
);
	// use a linked list to store the head and tail pointer of each price level.
	// also include both sides: bids and asks.

	logic [PTR_QUEUE-1:0]          	bids_head[0:PRICE_LEVELS-1];
	logic [PTR_QUEUE-1:0]          	asks_head[0:PRICE_LEVELS-1];

	logic [PTR_QUEUE-1:0]          	bids_tail[0:PRICE_LEVELS-1];
	logic [PTR_QUEUE-1:0]          	asks_tail[0:PRICE_LEVELS-1];

	// a free list of unused queue IDs.
	logic [PTR_QUEUE-1:0]		   	free_head;
	logic [PTR_QUEUE-1:0]			free_tail;
	logic [PTR_QUEUE-1:0]			free_next[MAX_QUEUES];

	// “next” pointer for each allocated queue in its price chain
  	logic [PTR_QUEUE-1:0] 			next_queue [MAX_QUEUES];

	logic [MAX_QUEUES-1:0][1:0]            op_flag_i;
	logic [MAX_QUEUES-1:0][PTR_WIDTH-1:0]  op_index_i;
	logic [MAX_QUEUES-1:0][DATA_SIZE-1:0]  op_data_i;
  	logic [MAX_QUEUES-1:0]                 op_valid_i;

	logic [MAX_QUEUES-1:0][DATA_SIZE-1:0]  pop_data_i;
	logic [MAX_QUEUES-1:0]                 full_i, empty_i, error_reg_i, error_rem_i, error_time_i;
	logic [MAX_QUEUES-1:0][PTR_WIDTH:0]    size_i;

	generate
		for (int j = 0; j < MAX_QUEUES; j++) begin: QUEUES
			queue # (
				.DATA_SIZE(DATA_SIZE),
				.FIFO_SIZE(FIFO_SIZE),
				.SCAN_SIZE(16)
			) u_queue (
				.clk 	(clk),
				.reset	(reset),

				.op_flag     (op_flag_i[j]),
				.op_index    (op_index_i[j]),
				.op_data     (op_data_i[j]),
        		.op_valid    (op_valid_i[j]),
				.pop_data    (pop_data_i[j]),
				.full        (full_i[j]),
				.empty       (empty_i[j]),
				.size        (size_i[j]),
				.error_reg   (error_reg_i[j]),
				.error_rem   (error_rem_i[j]),
				.error_time  (error_time_i[j])
			);
		end
	endgenerate

	// In this implementation a Queue ID = 0 means nullptr. 
	
	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			free_head = 1;
			for (int i = 1; i < MAX_QUEUES-1; i++) begin
				free_next[i] <= i+1;
			end
			free_next[MAX_QUEUES-1] <= 0;  
			free_tail <= MAX_QUEUES-1;

			for (int i = 0; i < PRICE_LEVELS; i++) begin
				bids_head[i] <= 0;
				bids_tail[i] <= 0;
				asks_head[i] <= 0;
				asks_tail[i] <= 0;
			end
    	end
  	end

	logic [PTR_QUEUE-1:0] nqueue;
	always_comb begin
		op_valid_i = '0;                      
		op_flag_i  = '{default: 2'b00};       
		op_index_i = '{default: '0};           
		op_data_i  = '{default: '0};  
		nqueue 	   = 0;
		case (op_flag)
			2'b00: begin
				logic [PTR_QUEUE-1:0] price_tail = (side) ? (asks_tail[price]) : (bids_tail[price]);
				logic [PTR_QUEUE-1:0] price_head = (side) ? (asks_head[price]) : (bids_head[price]);

				if (price_head == PTR_QUEUE'(0) || full_i[price_tail]) begin //empty pricelevel
					nqueue = free_head;
					free_head = free_next[nqueue];
					if (free_head == PTR_QUEUE'(0)) free_tail = PTR_QUEUE'(0); // all used? should not happen. TODO: Set error flags.

					if (price_head == PTR_QUEUE'(0)) begin
						if (side) begin
							asks_head[price] = nqueue;
							asks_tail[price] = nqueue;
						end else begin
							bids_head[price] = nqueue;
							bids_tail[price] = nqueue;
						end
					end else begin
						next_queue[price_tail]   	= nqueue;	
						if (side) begin
							asks_tail[price]    = nqueue;
						end else begin
							bids_tail[price]    = nqueue;
						end
					end
					next_queue[nqueue]  = PTR_QUEUE'(0);
				end else begin
					nqueue = price_tail;
				end

				op_valid_i[nqueue]  = 1;
				op_flag_i[nqueue]   = 2'b00;
				op_index_i[nqueue]  = 0;//We don't care about index when ADD.
				op_data_i[nqueue]   = op_data;
			end

			2'b10, 2'b11: begin
				op_valid_i[op_q_index] = 1;
				op_flag_i[op_q_index]  = op_flag;
				op_index_i[op_q_index] = op_index;
				op_data_i[op_q_index]  = op_data;
			end

			// TODO: Matching
		endcase        
	end

endmodule

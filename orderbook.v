`define DECL_PRI_ENC_HIGH(N, FN)                                         \
  function automatic logic [$clog2(N):0] FN (input logic [N-1:0] v);\
    int i;                                                          \
    for (i = N-1; i >= 0; i--)                                       \
      if (v[i]) begin FN = i; return; end                           \
    FN = N;                                                         \
  endfunction

`define DECL_PRI_ENC_LOW(N, FN)                                         \
  function automatic logic [$clog2(N):0] FN (input logic [N-1:0] v);\
    int i;                                                          \
    for (i = 0; i < N; i++)                                       \
      if (v[i]) begin FN = i; return; end                           \
    FN = N;                                                         \
  endfunction

//TODO: Refactor the comb logics into 2 stages: one for all priority encode, next pointers, 
module orderbook #(
	parameter DATA_SIZE    = 64,
	parameter FIFO_SIZE    = 64,
	parameter PTR_WIDTH    = $clog2(FIFO_SIZE),
	parameter PRICE_LEVELS = 256,
	parameter PRICE_WIDTH  = $clog2(PRICE_LEVELS),
	parameter MAX_QUEUES   = 1024,
	parameter PTR_QUEUE    = $clog2(MAX_QUEUES),
	parameter BIT_SCAN	   = 16,
	parameter BIT_SCAN_WIDTH = $clog2(BIT_SCAN)
)(
	input  logic                   clk,
	input  logic                   reset,

	// 100=add,101=match,110=remove,111=modify, 000=idle
	input  logic [2:0]             op_flag,
	input  logic                   side,   // 0=bid,1=ask
	input  logic [PRICE_WIDTH-1:0] price,
	input  logic [PTR_QUEUE-1:0]   op_q_index,
	input  logic [PTR_WIDTH-1:0]   op_index,
	input  logic [DATA_SIZE-1:0]   op_data,

	// match pops one per cycle
	//output logic [DATA_SIZE-1:0]   ob_pop_data,

	// Should log the trades somewhere (or not?)
	output logic                   matching // matching in progress
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

	logic [MAX_QUEUES-1:0][2:0]            op_flag_i;
	logic [MAX_QUEUES-1:0][PTR_WIDTH-1:0]  op_index_i;
	logic [MAX_QUEUES-1:0][DATA_SIZE-1:0]  op_data_i;
  	logic [MAX_QUEUES-1:0]                 op_valid_i;

	logic [MAX_QUEUES-1:0][DATA_SIZE-1:0]  pop_data_i;
	logic [MAX_QUEUES-1:0]                 full_i, empty_i, error_reg_i, error_rem_i, error_time_i;
	logic [MAX_QUEUES-1:0][PTR_WIDTH:0]    size_i;
	logic [MAX_QUEUES-1:0][PTR_WIDTH-1:0]  head_ptr_i;

	logic [BIT_SCAN-1:0] 		bid_grp_valid, 	ask_grp_valid;
	logic [BIT_SCAN_WIDTH:0]  best_bid_grp, 	best_ask_grp;
	logic [BIT_SCAN_WIDTH-1:0]  best_bid_lo,  	best_ask_lo;
	logic [PRICE_WIDTH-1:0]  	best_bid,     	best_ask;
	logic [PRICE_LEVELS-1:0] 	bid_active, 	ask_active;
	logic 						bid_empty,      ask_empty;

	logic [PTR_QUEUE-1:0]          	next_bids_head;
	logic [PTR_QUEUE-1:0]          	next_bids_tail;
	logic [PTR_QUEUE-1:0]          	next_asks_head;
	logic [PTR_QUEUE-1:0]          	next_asks_tail;
	logic 							next_bid_active;
	logic							next_ask_active;
	
	logic [PTR_QUEUE-1:0]			next_free_next_first;
	logic [PTR_QUEUE-1:0]			next_free_next_second;
	logic [PTR_QUEUE-1:0]			next_free_tail;

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
				.pop_data    (pop_data_i[j]),
				.full        (full_i[j]),
				.empty       (empty_i[j]),
				.size        (size_i[j]),
				.head_ptr	 (head_ptr_i[j]),
				.error_reg   (error_reg_i[j]),
				.error_rem   (error_rem_i[j]),
				.error_time  (error_time_i[j])
			);
		end
	endgenerate

	// group them into 16 groups of 16
	`DECL_PRI_ENC_HIGH(BIT_SCAN,  priority_encode_highBS)
	`DECL_PRI_ENC_LOW(BIT_SCAN,  priority_encode_lowBS)

	always_comb begin
		for (int g = 0; g < BIT_SCAN; g++) begin
			bid_grp_valid[g] = |bid_active[g*BIT_SCAN +: BIT_SCAN];
			ask_grp_valid[g] = |ask_active[g*BIT_SCAN +: BIT_SCAN];
		end

		best_bid_grp = priority_encode_highBS(bid_grp_valid);
		best_ask_grp = priority_encode_lowBS (ask_grp_valid);

		if (best_bid_grp != BIT_SCAN) begin //Careful! best_bid_grp should have 1 extra bit than best_bid_lo
			best_bid_lo  = priority_encode_highBS(bid_active[best_bid_grp*BIT_SCAN +: BIT_SCAN]);
			best_bid = best_bid_grp * BIT_SCAN + best_bid_lo;
			bid_empty = 0;
		end else begin
			bid_empty = 1;
		end

		if (best_ask_grp != BIT_SCAN) begin
			best_ask_lo  = priority_encode_lowBS(ask_active[best_ask_grp*BIT_SCAN +: BIT_SCAN]);
			best_ask = best_ask_grp * BIT_SCAN + best_ask_lo;
			ask_empty = 0;
		end else begin 
			ask_empty = 1;
		end
		next_bids_head = bids_head[best_bid];
		next_bids_tail = bids_tail[best_bid];
		next_asks_head = asks_head[best_ask];
		next_asks_tail = asks_tail[best_ask];
		next_bid_active = bid_active[best_bid];
		next_ask_active = bid_active[best_ask];
	end

	// In this implementation a Queue ID = 0 means nullptr. 
	
	logic [PTR_QUEUE-1:0] nqueue;
	logic				  is_matching;

	always_comb begin             
		op_flag_i  = '{default: 3'b000};       
		op_index_i = '{default: '0};           
		op_data_i  = '{default: '0};  
		nqueue 	   = 0;
		next_free_next = free_next[free_tail];
		next_free_tail = free_tail;
		is_matching = 0;
		case (op_flag)
			3'b100: begin
				logic [PTR_QUEUE-1:0] price_tail = (side) ? (asks_tail[price]) : (bids_tail[price]);
				logic [PTR_QUEUE-1:0] price_head = (side) ? (asks_head[price]) : (bids_head[price]);

				if (price_head == '0 || full_i[price_tail]) begin //empty pricelevel
					nqueue = free_head;
				end else begin
					nqueue = price_tail;
				end

				op_flag_i[nqueue]   = 3'b100;
				op_index_i[nqueue]  = 0;//We don't care about index when ADD.
				op_data_i[nqueue]   = op_data;
			end

			3'b110, 3'b111: begin
				op_flag_i[op_q_index]  = op_flag;
				op_index_i[op_q_index] = op_index;
				op_data_i[op_q_index]  = op_data;
			end

			3'b101: begin // Matching
				if (!ask_empty && !bid_empty && best_ask < best_bid) begin // The orderbook should be fully matched before next matching happens.
					// We assume the 16-31th bits are "quantity" field.
					is_matching = 1;
					logic [PTR_QUEUE-1:0] bid_queue_ptr = bids_head[best_bid];
					logic [PTR_QUEUE-1:0] ask_queue_ptr = asks_head[best_ask];
					logic [PTR_WIDTH-1:0] bid_queue_size = size_i[bid_queue_ptr];
					logic [PTR_WIDTH-1:0] ask_queue_size = size_i[ask_queue_ptr];

					if (!error_time_i[bid_queue_ptr] && !error_time_i[ask_queue_ptr] && bid_queue_size && ask_queue_size) begin

						logic [DATA_SIZE-1:0] bid_word = pop_data_i[bid_queue_ptr];
						logic [DATA_SIZE-1:0] ask_word = pop_data_i[ask_queue_ptr];

						logic [15:0] bid_qty = bid_word[31:16];
						logic [15:0] ask_qty = ask_word[31:16];
						logic [15:0] trade_qty = (bid_qty < ask_qty) ? bid_qty : ask_qty;

						logic [15:0] bid_rem = bid_qty - trade_qty;
						logic [15:0] ask_rem = ask_qty - trade_qty;

						logic [DATA_SIZE-1:0] new_bid_data = { bid_word[63:32], bid_rem, bid_word[15:0] };
						logic [DATA_SIZE-1:0] new_ask_data = { ask_word[63:32], ask_rem, ask_word[15:0] };

						if (bid_rem == 0) begin
							op_flag_i[bid_queue_ptr]  = 3'b101;             // pop
							op_index_i[bid_queue_ptr] = head_ptr_i[bid_queue_ptr];
							bid_queue_size -= 1;
						end else begin
							op_flag_i[bid_queue_ptr]  = 3'b111;             // modify
							op_index_i[bid_queue_ptr] = head_ptr_i[bid_queue_ptr];
							op_data_i[bid_queue_ptr]  = new_bid_data;
						end

						if (ask_rem == 0) begin
							op_flag_i[ask_queue_ptr]  = 3'b101;             
							op_index_i[ask_queue_ptr] = head_ptr_i[ask_queue_ptr];
							ask_queue_size -= 1;
						end else begin
							op_flag_i[ask_queue_ptr]  = 3'b111;             
							op_index_i[ask_queue_ptr] = head_ptr_i[ask_queue_ptr];
							op_data_i[ask_queue_ptr]  = new_ask_data;
						end
					end 
					if (bid_queue_size == 0) begin
						logic [PTR_QUEUE-1:0] bid_next_queue = next_queue[bid_queue_ptr];
						if (bid_next_queue == '0) begin
							next_bids_tail = '0;
							next_bid_active = '0;
						end
						next_bids_head = bid_next_queue;
						next_free_next = bid_queue_ptr;
						next_free_tail = bid_queue_ptr;
					end else if (ask_queue_size == 0) begin
						logic [PTR_QUEUE-1:0] ask_next_queue = next_queue[ask_queue_ptr];
						if (ask_next_queue == '0) begin
							next_asks_tail = '0;
							next_ask_active = '0;
						end
						next_asks_head = ask_next_queue;
						next_free_next = ask_queue_ptr;
						next_free_tail = ask_queue_ptr;
					end
					// TODO : need to call the hashmap to remove the entry when done.
				end
			end
		endcase        
	end

	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			bid_active <= 0;
    		ask_active <= 0;
			free_head <= 1;
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
		end else begin
			case (op_flag)
				3'b100: begin
					logic [PTR_QUEUE-1:0] price_tail = (side) ? (asks_tail[price]) : (bids_tail[price]);
					logic [PTR_QUEUE-1:0] price_head = (side) ? (asks_head[price]) : (bids_head[price]);

					if (price_head == '0 || full_i[price_tail]) begin //empty pricelevel
						free_head <= free_next[nqueue];
						//if (free_head == PTR_QUEUE'(0)) free_tail = PTR_QUEUE'(0); // all used? should not happen. TODO: Set error flags.

						if (price_head == '0) begin
							if (side) begin
								asks_head[price] <= nqueue;
    							ask_active[price] <= 1;
								asks_tail[price] <= nqueue;
							end else begin
								bids_head[price] <= nqueue;
								bid_active[price] <= 1;
								bids_tail[price] <= nqueue;
							end
						end else begin
							next_queue[price_tail]  <= nqueue;	
							if (side) begin
								asks_tail[price]    <= nqueue;
							end else begin
								bids_tail[price]    <= nqueue;
							end
						end
						next_queue[nqueue]  <= '0;
					end 
				end
			endcase
			bids_head[best_bid] <= next_bids_head;
			bids_tail[best_bid] <= next_bids_tail;
			asks_head[best_ask] <= next_asks_head;
			asks_tail[best_ask] <= next_asks_tail;
			bid_active[best_bid] <= next_bid_active;
			ask_active[best_ask] <= next_ask_active;
			free_next[free_tail] <= next_free_next;
			free_tail			<= next_free_tail; 
		end
  	end

	assign matching = is_matching;
endmodule

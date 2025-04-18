module orderbook #(
  parameter DATA_SIZE    = 64,
  parameter FIFO_SIZE    = 64,
  parameter PTR_WIDTH    = $clog2(FIFO_SIZE),
  parameter PRICE_LEVELS = 256,
  parameter PRICE_WIDTH  = $clog2(PRICE_LEVELS),
  parameter MAX_QUEUES   = 512,
  parameter QID_WIDTH    = $clog2(MAX_QUEUES),
  parameter MAX_PER_PL   = 8         // max queues you’ll ever attach per price
)(
  input  logic                   clk,
  input  logic                   reset,

  // 00=add,01=match,10=remove,11=modify
  input  logic [1:0]             ob_op,
  input  logic                   side,   // 0=bid,1=ask
  input  logic [PRICE_WIDTH-1:0] price,
  input  logic [PTR_WIDTH-1:0]   ob_index,
  input  logic [DATA_SIZE-1:0]   ob_data,

  // match pops one per cycle
  output logic [DATA_SIZE-1:0]   ob_pop_data,
  output logic                   matching_in_progress
);

  // —— book tables —— 
  // for each side+price: list of active queue‐IDs, and a count
  logic [QID_WIDTH-1:0] pl_q  [0:1][0:PRICE_LEVELS-1][0:MAX_PER_PL-1];
  logic [$clog2(MAX_PER_PL+1)-1:0]  pl_cnt [0:1][0:PRICE_LEVELS-1];

  // —— instantiate the pool —— 
  logic                   alloc_req, alloc_ack;
  logic [QID_WIDTH-1:0]   alloc_qid;
  logic                   free_req;
  logic [QID_WIDTH-1:0]   free_qid;

  logic                   op_valid;
  logic [QID_WIDTH-1:0]   op_qid;
  logic [1:0]             op_flag;
  logic [PTR_WIDTH-1:0]   op_index;
  logic [DATA_SIZE-1:0]   op_data;
  logic                   full, empty;
  logic [PTR_WIDTH:0]     size;
  logic [DATA_SIZE-1:0]   pop_data;

  queue_pool #(
    .DATA_SIZE (DATA_SIZE),
    .FIFO_SIZE (FIFO_SIZE),
    .PTR_WIDTH (PTR_WIDTH),
    .MAX_QUEUES(MAX_QUEUES),
    .QID_WIDTH (QID_WIDTH)
  ) pool (
    .clk         (clk),
    .reset       (reset),
    // alloc/free
    .alloc_req   (alloc_req),
    .alloc_ack   (alloc_ack),
    .alloc_qid   (alloc_qid),
    .free_req    (free_req),
    .free_qid    (free_qid),
    // op iface
    .op_valid    (op_valid),
    .op_qid      (op_qid),
    .op_flag     (op_flag),
    .op_index    (op_index),
    .op_data     (op_data),
    .pop_data    (pop_data),
    .full        (full),
    .empty       (empty),
    .size        (size),
    .err_reg     (),
    .err_rem     (),
    .err_time    ()
  );

  // —— state for matching —— 
  typedef enum logic { IDLE, MATCHING } st_t;
  st_t       state, nxt;
  logic      start_m;
  logic [PRICE_WIDTH-1:0]  match_price;
  logic [$clog2(MAX_PER_PL)-1:0] match_slot;
  logic      match_side;

  assign start_m = (state==IDLE && ob_op==2'b01);

  //— FSM — 
  always_comb begin
    nxt = state;
    unique case (state)
      IDLE:     if (start_m)                    nxt = MATCHING;
      MATCHING: if ( /* no queues left on match_side */ ) nxt = IDLE;
    endcase
  end
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin state<=IDLE; match_side<=0; end
    else begin
      if (start_m)     match_side <= side;
      state            <= nxt;
    end
  end

  //—— dynamic allocation on ADD ——
  always_ff @(posedge clk) begin
    alloc_req <= 0;
    if (state==IDLE && ob_op==2'b00) begin
      // need to push to one of pl_q[side][price][0..cnt-1]
      if (pl_cnt[side][price]==0 
          || full /* last queue is full */ ) begin
        // grab a fresh context
        alloc_req <= 1;
      end
    end

    if (alloc_ack) begin
      // append new queue‐ID
      pl_q[side][price][ pl_cnt[side][price] ] <= alloc_qid;
      pl_cnt[side][price] <= pl_cnt[side][price] + 1;
    end
  end

  //—— build op interface each cycle ——
  always_comb begin
    op_valid = 0;
    alloc_qid; free_req <= 0; // default

    if (state==IDLE) begin
      case (ob_op)
        2'b00: begin  // ADD
          // choose last queue‐ID
          op_qid   = pl_q[side][price][ pl_cnt[side][price]-1 ];
          op_flag  = ob_op;
          op_data  = ob_data;
          op_valid = 1;
        end
        2'b10,2'b11: begin  // remove/modify
          // you need to track which queue‐ID your index refers to;
          // for simplicity assume ob_index is encoded {slot,idx}
          op_qid   = pl_q[side][price][ ob_index[PTR_WIDTH +: $clog2(MAX_PER_PL)] ];
          op_flag  = ob_op;
          op_index = ob_index[PTR_WIDTH-1:0];
          op_valid = 1;
        end
        default: ;
      endcase
    end
    else if (state==MATCHING) begin
      // pick next nonempty queue in price
      // (scan through pl_q[match_side][match_price][0..cnt-1])
      // set match_price,match_slot here
      // then:
      op_qid   = pl_q[match_side][match_price][match_slot];
      op_flag  = 2'b01;    // pop
      op_valid = 1;
      // when that queue empties, free it:
      if ( /* empty soon */ ) begin
        free_req <= 1;
        free_qid <= op_qid;
        // remove it from pl_q list, decrement pl_cnt...
      end
    end
  end

  // finally hook pool’s pop_data out
  assign ob_pop_data = pop_data;
  assign matching_in_progress = (state==MATCHING);

endmodule

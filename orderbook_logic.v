//-----------------------------------------------------------------------------
// Module: OrderBookLogic
// Description:
//   Receives parsed market feed and determines what action to take for an order.
//   Outputs signals for Order ID Lookup and Price 1v1 Manager modules.
//   Handles logic for NEW, MODIFY, CANCEL order types.
//-----------------------------------------------------------------------------

module OrderBookLogic ( // Start of the OrderBookLogic module
    // these are all the things that we would need to edit based off of the parser data
    input  wire        clk,                     // System clock signal
    input  wire        rst_n,                   // Active-low asynchronous reset
    input  wire [31:0] order_id,                // Unique identifier for the order
    input  wire [1:0]  order_type,              // Type of order: 00 = NEW, 01 = MODIFY, 10 = CANCEL
    input  wire [0:0]  side,                    // Side of order: 0 = BUY, 1 = SELL
    input  wire [31:0] price,                   // Price associated with the order
    input  wire [31:0] quantity,                // Quantity of units in the order

    output reg  [31:0] to_order_id_lookup_order_id,     // Output: order_id to be sent to Order ID Lookup module
    output reg  [1:0]  to_order_id_lookup_action_type,  // Output: action type to be sent to Order ID Lookup module

    output reg  [0:0]  to_price_1v1_mgr_side,            // Output: side to be sent to Price 1v1 Manager
    output reg  [31:0] to_price_1v1_mgr_price,           // Output: price to be sent to Price 1v1 Manager
    output reg  [31:0] to_price_1v1_mgr_quantity,        // Output: quantity to be sent to Price 1v1 Manager
    output reg  [1:0]  to_price_1v1_mgr_action_type      // Output: action type to be sent to Price 1v1 Manager
);

//-----------------------------------------------------------------------------
// ENUM Definitions for clarity (as localparams)
//-----------------------------------------------------------------------------

localparam [1:0]
    ORDER_NEW    = 2'b00,  // Order type representing a new order
    ORDER_MODIFY = 2'b01,  // Order type representing a modification of an existing order
    ORDER_CANCEL = 2'b10;  // Order type representing a cancellation of an existing order

localparam [1:0]
    ACTION_ADD    = 2'b00, // Action type representing an add operation
    ACTION_MODIFY = 2'b01, // Action type representing a modify operation
    ACTION_REMOVE = 2'b10; // Action type representing a remove operation

//-----------------------------------------------------------------------------
// Internal registers
//-----------------------------------------------------------------------------

reg [1:0] action_type_reg; // Internal register to store action type determined by input order_type

//-----------------------------------------------------------------------------
// Main Sequential Logic Block
//-----------------------------------------------------------------------------

always @(posedge clk or negedge rst_n) begin // Triggered on rising clock edge or falling reset
    if (!rst_n) begin // If reset is active (low)
        to_order_id_lookup_order_id    <= 32'd0; // Reset order ID output to 0
        to_order_id_lookup_action_type <= 2'd0;  // Reset order action output to 0

        to_price_1v1_mgr_side          <= 1'b0;  // Reset side output to BUY (0)
        to_price_1v1_mgr_price         <= 32'd0; // Reset price output to 0
        to_price_1v1_mgr_quantity      <= 32'd0; // Reset quantity output to 0
        to_price_1v1_mgr_action_type   <= 2'd0;  // Reset price action output to 0

        action_type_reg                <= 2'd0;  // Reset internal action register to 0 (default ADD)
    end
    else if (order_valid) begin // If the order input is valid (order_valid == 1)

        // Determine the action type based on the order_type input
        case (order_type)
            ORDER_NEW: begin // If the order is NEW
                action_type_reg <= ACTION_ADD; // Set action to ADD
            end
            ORDER_MODIFY: begin // If the order is MODIFY
                action_type_reg <= ACTION_MODIFY; // Set action to MODIFY
            end
            ORDER_CANCEL: begin // If the order is CANCEL
                action_type_reg <= ACTION_REMOVE; // Set action to REMOVE
            end
            default: begin // Catch-all default case
                action_type_reg <= ACTION_ADD; // Default to ADD (safe fallback)
            end
        endcase

        // Send data to Order ID Lookup block
        to_order_id_lookup_order_id    <= order_id;         // Forward the order ID
        to_order_id_lookup_action_type <= action_type_reg;  // Forward the determined action

        // Send data to Price 1v1 Manager block
        to_price_1v1_mgr_side          <= side;             // Forward the side (BUY/SELL)
        to_price_1v1_mgr_price         <= price;            // Forward the price
        to_price_1v1_mgr_quantity      <= quantity;         // Forward the quantity
        to_price_1v1_mgr_action_type   <= action_type_reg;  // Forward the action
    end
    // If order_valid is not high, do nothing; retain previous output values
end // End of always block

endmodule // End of OrderBookLogic module

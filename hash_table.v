module hash_table #(
    parameter KEY_WIDTH   = 32,
    parameter VALUE_WIDTH = 32,
    parameter TABLE_SIZE  = 16,
    parameter INDEX_WIDTH = 4  // log2(TABLE_SIZE)
)(
    input                         clk,
    input      [KEY_WIDTH-1:0]    key,
    input      [VALUE_WIDTH-1:0]  value_in,
    input                         insert,
    input                         lookup,
    output reg [VALUE_WIDTH-1:0]  value_out,
    output reg                    found
);

    reg [KEY_WIDTH-1:0]    keys   [0:TABLE_SIZE-1];
    reg [VALUE_WIDTH-1:0]  values [0:TABLE_SIZE-1];
    reg                    valid  [0:TABLE_SIZE-1];

    wire [INDEX_WIDTH-1:0] index;
    assign index = key[INDEX_WIDTH-1:0];  // simple hash: low bits

    integer i;
    initial begin
        for (i = 0; i < TABLE_SIZE; i = i + 1) begin
            keys[i] = 0;
            values[i] = 0;
            valid[i] = 0;
        end
    end

    always @(posedge clk) begin
        // Default outputs
        value_out <= 0;
        found     <= 0;

        if (insert) begin
            keys[index]   <= key;
            values[index] <= value_in;
            valid[index]  <= 1;
            value_out     <= value_in;
            found         <= 1;
        end else if (lookup) begin
            if (valid[index] && keys[index] == key) begin
                value_out <= values[index];
                found     <= 1;
            end
        end
    end

endmodule

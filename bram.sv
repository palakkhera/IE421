/*
BRAM --> Block Random Access Memory
  - Used to store large amounts of memory in your FPGA
  - Close proximity to the FPGA logic circuits --> high speed access 
  - Good for rapid retrieval 
  - Often used to store Lookup tables or fast-access buffers
  - True Dual Port
    Allows you to read and write from both sides simultaneously

Inputs:
  clk                : Clock signal
  we_a, we_b         : Write enables for Port A and Port B
  addr_a, addr_b     : Addresses for Port A and Port B
  din_a, din_b       : Data inputs for Port A and Port B

Outputs:
  dout_a, dout_b     : Data outputs for Port A and Port B

Goal:
  Implement a True Dual Port BRAM
  Provide fast and efficient memory storage for order book data
*/

module bram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter DEPTH = 1 << ADDR_WIDTH
)(
    input  logic clk,

    // Port A
    input  logic we_a,
    input  logic [ADDR_WIDTH-1:0] addr_a,
    input  logic [DATA_WIDTH-1:0] din_a,
    output logic [DATA_WIDTH-1:0] dout_a,

    // Port B
    input  logic we_b,
    input  logic [ADDR_WIDTH-1:0] addr_b,
    input  logic [DATA_WIDTH-1:0] din_b,
    output logic [DATA_WIDTH-1:0] dout_b
);

    // Memory declaration
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge clk) begin
        // Port A logic
        if (we_a)
            mem[addr_a] <= din_a;
        dout_a <= mem[addr_a];

        // Port B logic
        if (we_b)
            mem[addr_b] <= din_b;
        dout_b <= mem[addr_b];
    end

endmodule

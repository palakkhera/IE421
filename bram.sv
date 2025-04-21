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
    parameter DATA_WIDTH = 32,         // Width of each memory entry
    parameter ADDR_WIDTH = 10,         // Width of address (2^ADDR_WIDTH = number of entries)
    parameter DEPTH = 1 << ADDR_WIDTH  // Total number of memory entries
)(
    input  logic clk,                  // System clock

    // Port A interface
    input  logic we_a,                                 // Write enable for Port A
    input  logic [ADDR_WIDTH-1:0] addr_a,              // Address for Port A
    input  logic [DATA_WIDTH-1:0] din_a,               // Data input for Port A
    output logic [DATA_WIDTH-1:0] dout_a,              // Data output for Port A

    // Port B interface
    input  logic we_b,                                 // Write enable for Port B
    input  logic [ADDR_WIDTH-1:0] addr_b,              // Address for Port B
    input  logic [DATA_WIDTH-1:0] din_b,               // Data input for Port B
    output logic [DATA_WIDTH-1:0] dout_b               // Data output for Port B
);
    //create a memory array with depth entries of DATA_WIDTH bits
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge clk) begin
        //Port A
        //if write enable is high, store din_a at address addr_a
        if (we_a)
            mem[addr_a] <= din_a;

        //always read from memory at addr_a and assign to dout_a
        dout_a <= mem[addr_a];

        //Port B
        //if write enable is high, store din_b at address addr_b
        if (we_b)
            mem[addr_b] <= din_b;

        //always read from memory at addr_b and assign to dout_b
        dout_b <= mem[addr_b];
    end

endmodule

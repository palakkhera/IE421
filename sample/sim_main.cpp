// sim_main.cpp
#include "Vhello.h"
#include "verilated.h"

int main() {
    const char* argv[] = {};
    Verilated::commandArgs(0, argv);

    Vhello* top = new Vhello;
    top->eval();  // Run the Verilog initial block
    delete top;
    return 0;
}
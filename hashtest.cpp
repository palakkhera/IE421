#include "Vhash_table.h"
#include "verilated.h"
#include <iostream>

int main() {
    Verilated::commandArgs(0, (const char**) nullptr);
    Vhash_table* top = new Vhash_table;

    // Reset state
    top->clk = 0;
    top->eval();

    // Step 1: Insert key=42, value=99
    top->key = 42;
    top->value_in = 99;
    top->insert = 1;
    top->lookup = 0;

    // Toggle clk to register insert
    top->clk = 1;
    top->eval();
    top->clk = 0;
    top->eval();

    std::cout << "Inserted key 42 with value 99\n";

    // Step 2: Lookup key=42
    top->key = 42;
    top->insert = 0;
    top->lookup = 1;

    // Toggle clk to trigger lookup
    top->clk = 1;
    top->eval();
    top->clk = 0;
    top->eval();

    if (top->found) {
        std::cout << "Lookup success: value = " << top->value_out << "\n";
    } else {
        std::cout << "Lookup failed.\n";
    }

    delete top;
    return 0;
}

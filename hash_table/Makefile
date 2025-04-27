# Makefile for building and simulating the Verilated hash_table

# Verilog source
VERILOG_SRC = hash_table.v

# C++ sources
CPP_SRCS = HashTable.cpp HashTableTest.cpp

# Top-level Verilated module name
TOP_MODULE = hash_table

# Verilator-generated executable
EXEC = obj_dir/V$(TOP_MODULE)

all: $(EXEC)

$(EXEC): $(VERILOG_SRC) $(CPP_SRCS)
	verilator -Wall --cc $(VERILOG_SRC) --exe $(CPP_SRCS) --build

test: $(EXEC)
	./$(EXEC)

clean:
	rm -rf obj_dir *.log *.vcd

.PHONY: all test clean

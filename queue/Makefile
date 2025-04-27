# Makefile for building and simulating the Verilated queue

# Verilog source
VERILOG_SRC = queue.v

# C++ sources
CPP_SRCS = Queue.cpp QueueTest.cpp

# Top-level Verilated module name
TOP_MODULE = queue

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
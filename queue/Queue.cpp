#include "Queue.hpp"

Queue::Queue() {
    dut = new Vqueue;
    reset();
}

void Queue::reset() {
    dut->reset = 1;
    step();
    dut->reset = 0;
}

void Queue::step() {
    dut->clk = 0;
    dut->eval();
    Verilated::timeInc(1);
    dut->clk = 1;
    dut->eval();
    Verilated::timeInc(1);
}

bool Queue::push(uint64_t data) {
    dut->op_flag = 0b00;
    dut->op_data = data;
    dut->op_index = 0;
    step();
    return !(dut->error_reg);
}

bool Queue::pop(uint64_t& out) {
    dut->op_flag = 0b01;
    dut->op_data = 0;
    dut->op_index = 0;
    step();
    if (!dut->error_time && !dut->error_reg) {
        out = dut->pop_data;
        return true;
    }
    return false;
}

bool Queue::remove(uint32_t index) {
    dut->op_flag = 0b10;
    dut->op_data = 0;
    dut->op_index = index;
    step();
    return !(dut->error_rem);
}

bool Queue::modify(uint32_t index, uint64_t data) {
    dut->op_flag = 0b11;
    dut->op_data = data;
    dut->op_index = index;
    step();
    return !(dut->error_rem);
}

bool Queue::is_full() const {
    return dut->full;
}

bool Queue::is_empty() const {
    return dut->empty;
}

uint32_t Queue::get_size() const {
    return dut->size;
}

#include "Queue.hpp"

Queue::Queue() {
    dut = new Vqueue;
    reset();
}

Queue::~Queue() {
    dut->final();
    delete dut;
}

void Queue::reset() {
    dut->rst = 1;
    step();
    dut->rst = 0;
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
    dut->op = PUSH;
    dut->value_in = data;
    step();
    return dut->success;
}

bool Queue::pop(uint64_t& out) {
    dut->op = POP;
    step();
    if (dut->success) {
        out = dut->value_out;
        return true;
    }
    return false;
}

bool Queue::peek(uint64_t& out) {
    dut->op = PEEK;
    step();
    if (dut->success) {
        out = dut->value_out;
        return true;
    }
    return false;
}

bool Queue::remove(uint32_t index) {
    dut->op = REMOVE;
    dut->index = index;
    step();
    return dut->success;
}

bool Queue::modify(uint32_t index, uint64_t data) {
    dut->op = MODIFY;
    dut->value_in = data;
    dut->index = index;
    step();
    return dut->success;
}

bool Queue::is_full() const {
    return dut->size >= QUEUE_CAPACITY;
}

bool Queue::is_empty() const {
    return dut->size == 0;
}

uint32_t Queue::get_size() const {
    return dut->size;
}

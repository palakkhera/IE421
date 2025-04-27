#include "HashTable.hpp"

HashTable::HashTable() {
    dut = new Vhash_table;
    reset();
}

HashTable::~HashTable() {
    dut->final();
    delete dut;
}

void HashTable::clear() {
    reset();
}

void HashTable::reset() {
    dut->rst = 1;
    step();
    dut->rst = 0;
}

void HashTable::eval_cycle() {
    dut->clk = 0;
    dut->eval();
    main_time++;

    dut->clk = 1;
    dut->eval();
    main_time++;
}

void HashTable::step() {
    do {
        eval_cycle();
    } while (dut->state != DONE);
}

bool HashTable::insert(uint32_t key, void* value) {
    dut->op = INSERT;
    dut->key = key;
    dut->value_in = reinterpret_cast<uintptr_t>(value);

    step();

    bool success = dut->success;
    dut->op = NOOP;
    return success;
}

bool HashTable::lookup(uint32_t key, void** value_out) {
    dut->op = LOOKUP;
    dut->key = key;

    step();

    bool success = dut->success;
    if (success) {
        *value_out = reinterpret_cast<void*>(dut->value_out);
    }

    dut->op = NOOP;
    return success;
}

bool HashTable::erase(uint32_t key) {
    dut->op = ERASE;
    dut->key = key;

    step();

    bool success = dut->success;
    dut->op = NOOP;
    return success;
}

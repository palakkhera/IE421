#pragma once

#include "Vhash_table.h"
#include "verilated.h"

class HashTable {
public:
    HashTable();
    ~HashTable();

    bool insert(uint32_t key, void* value);
    bool lookup(uint32_t key, void** value_out);
    bool erase(uint32_t key);

    void tick();  // advance clock

private:
    Vhash_table* dut;
    vluint64_t main_time = 0;

    void eval_cycle();
};


enum HashTableState { IDLE = 0, SEARCH = 1, DONE = 2 };
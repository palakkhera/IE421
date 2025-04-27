/**
 * @file HashTable.hpp
 * @brief C++ wrapper for the Verilated HashTable module.
 *
 * Provides an interface to insert, remove, and search for elements in a hardware hash table.
 * Handles clocking, reset, and operation status checking internally.
 *
 * Operations:
 * - insert(key, value): Inserts a (key, value) pair.
 * - remove(key): Removes an entry by key.
 * - search(key, value_out): Searches for a key and retrieves the value.
 * - clear(): Clears the hash table. Does NOT destruct any keys or values.
 *
 * State Machine:
 * - IDLE: Hash table is ready for a new command.
 * - BUSY: Hash table is processing a command.
 * - DONE: Command execution completed successfully.
 *
 * Notes:
 * - Operations are blocking and wait until the hardware signals completion.
 */

#pragma once

#include "Vhash_table.h"
#include "verilated.h"


// Edit these in hash_table.v too if any changes are needed.
enum HashTableState { IDLE = 0, SEARCHING = 1, INSERTING = 2, DONE = 3 };
enum HashTableOp { NOOP = 0, INSERT = 1, LOOKUP = 2, ERASE = 3 }; 

class HashTable {
public:

    HashTable();
    ~HashTable();

    /**
     * @brief Inserts a key-value pair into the hash table.
     * 
     * @param key The key to insert.
     * @param value The value associated with the key.
     * 
     * @return True if the operation was successful, false otherwise.
     */
    bool insert(uint32_t key, void* value);

    /**
     * @brief Searches for a key in the hash table.
     * 
     * @param key The key to search for.
     * @param value_out Pointer to an object to store the found value.
     * 
     * @return True if the key was found, false otherwise.
     */
    bool lookup(uint32_t key, void** value_out);

    /**
     * @brief Removes a key (and its value) from the hash table.
     * 
     * @param key The key to remove.
     * 
     * @return True if the operation was successful, false otherwise.
     */
    bool erase(uint32_t key);

    /**
     * @brief Clears all entries from the structure without deallocating memory.
     *
     * Resets all internal pointers without actually freeing or destructing 
     * any objects. 
     * 
     * Notes:
     * - Does NOT call any destructors or release any dynamic memory.
     * - Queue/HashTable remains allocated and ready for reuse after clear().
     */
    void clear();

private:
    Vhash_table* dut;
    vluint64_t main_time = 0;

    /**
     * @brief Advances until operation is complete.
     */
    void step();

    /**
     * @brief Advances one clock cycle.
     */
    void eval_cycle(); 

    /**
     * @brief Resets the state of the hash table.
     */
    void reset();
};

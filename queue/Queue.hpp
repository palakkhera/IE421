// C++ wrapper for the Verilog queue module
// Supports push, pop, remove, and modify operations
// Handles synchronization and error checking through Verilator simulation

#include <cstdint>
#include "Vqueue.h"
#include "verilated.h"


// Edit these in queue.v too if any changes are needed.
constexpr uint32_t QUEUE_CAPACITY = 65536;
enum QueueState { IDLE = 0, BUSY = 1, FLUSHING = 2, DONE = 3 }; // state
enum QueueOp { NOOP = 0, PUSH = 1, POP = 2, PEEK = 3, REMOVE = 4, MODIFY = 5 }; // operation

class Queue {
public:
    Queue();
    ~Queue();

    void reset();

    // Push a new element into the queue
    bool push(uint64_t data);

    // Pop the front element from the queue
    bool pop(uint64_t& out);

    // Read the front element of the queue
    bool peek(uint64_t& out);

    // Remove an element by index
    bool remove(uint32_t index);

    // Modify an element at a given index
    bool modify(uint32_t index, uint64_t data);

    // Query if the queue is full
    bool is_full() const;

    // Query if the queue is empty
    bool is_empty() const;

    // Get the current number of valid elements in the queue
    uint32_t get_size() const;

private:
    Vqueue* dut;

    // Advances until state reaches DONE
    void step();

    // Advances one clock cycle
    void eval_cycle();
};

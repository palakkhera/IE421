#include "Queue.hpp"
#include <cassert>

void test_enqueue_dequeue() {
    Queue q;
    assert(q.enqueue(10));
    assert(q.enqueue(20));
    uint32_t out;
    assert(q.dequeue(out));
    assert(out == 10);
    assert(q.dequeue(out));
    assert(out == 20);
    std::cout << "test_enqueue_dequeue passed\n";
}

void test_peek() {
    Queue q;
    assert(q.enqueue(42));
    uint32_t out;
    assert(q.peek(out));
    assert(out == 42);
    assert(q.dequeue(out));
    assert(out == 42);
    std::cout << "test_peek passed\n";
}

void test_empty_dequeue() {
    Queue q;
    uint32_t out;
    assert(!q.dequeue(out));
    std::cout << "test_empty_dequeue passed\n";
}

void test_fill_and_empty(int count) {
    Queue q;
    for (int i = 0; i < count; i++) {
        assert(q.enqueue(i));
    }
    for (int i = 0; i < count; i++) {
        uint32_t out;
        assert(q.dequeue(out));
        assert(out == i);
    }
    std::cout << "test_fill_and_empty passed\n";
}

void test_interleaved_ops() {
    Queue q;
    uint32_t out;
    assert(q.enqueue(1));
    assert(q.enqueue(2));
    assert(q.dequeue(out) && out == 1);
    assert(q.enqueue(3));
    assert(q.dequeue(out) && out == 2);
    assert(q.dequeue(out) && out == 3);
    std::cout << "test_interleaved_ops passed\n";
}

int main() {
    test_enqueue_dequeue();
    test_peek();
    test_empty_dequeue();
    test_fill_and_empty(16);
    test_interleaved_ops();

    std::cout << "All tests passed!\n";
    return 0;
}
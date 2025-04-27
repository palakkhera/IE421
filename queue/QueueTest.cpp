#include "Queue.hpp"
#include <cassert>
#include <iostream>

void test_enqueue_dequeue() {
    Queue q;
    assert(q.push(10));
    assert(q.push(20));
    uint64_t out;
    assert(q.pop(out));
    assert(out == 10);
    assert(q.pop(out));
    assert(out == 20);
    std::cout << "test_enqueue_dequeue passed\n";
}

void test_peek() {
    Queue q;
    assert(q.push(42));
    uint64_t out;
    assert(q.peek(out));
    assert(out == 42);
    assert(q.pop(out));
    assert(out == 42);
    std::cout << "test_peek passed\n";
}

void test_empty_dequeue() {
    Queue q;
    uint64_t out;
    assert(!q.pop(out));
    std::cout << "test_empty_dequeue passed\n";
}

void test_fill_and_empty(int count) {
    Queue q;
    for (int i = 0; i < count; i++) {
        assert(q.push(i));
    }
    for (int i = 0; i < count; i++) {
        uint64_t out;
        assert(q.pop(out));
        assert(out == i);
    }
    std::cout << "test_fill_and_empty passed\n";
}

void test_interleaved_ops() {
    Queue q;
    uint64_t out;
    assert(q.push(1));
    assert(q.push(2));
    assert(q.pop(out) && out == 1);
    assert(q.push(3));
    assert(q.pop(out) && out == 2);
    assert(q.pop(out) && out == 3);
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
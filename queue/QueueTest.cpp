#include "Queue.hpp"
#include <cassert>

void test_enqueue_dequeue(queue& q) {
    q.reset();
    assert(q.enqueue(10));
    assert(q.enqueue(20));
    uint32_t out;
    assert(q.dequeue(out));
    assert(out == 10);
    assert(q.dequeue(out));
    assert(out == 20);
    std::cout << "test_enqueue_dequeue passed\n";
}

void test_peek(queue& q) {
    q.reset();
    assert(q.enqueue(42));
    uint32_t out;
    assert(q.peek(out));
    assert(out == 42);
    assert(q.dequeue(out));
    assert(out == 42);
    std::cout << "test_peek passed\n";
}

void test_empty_dequeue(queue& q) {
    q.reset();
    uint32_t out;
    assert(!q.dequeue(out));
    std::cout << "test_empty_dequeue passed\n";
}

void test_fill_and_empty(queue& q, int count) {
    q.reset();
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

void test_interleaved_ops(queue& q) {
    q.reset();
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
    Queue q;

    test_enqueue_dequeue(q);
    test_peek(q);
    test_empty_dequeue(q);
    test_fill_and_empty(q, 16);
    test_interleaved_ops(q);

    std::cout << "All tests passed!\n";
    return 0;
}
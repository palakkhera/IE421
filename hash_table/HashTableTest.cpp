#include <cassert>
#include <iostream>
#include "HashTable.hpp"

struct SimpleOrderBookEntry {
    int price;
    int size;
};

void test_insert_and_lookup() {
    HashTable ht;

    SimpleOrderBookEntry* ob = new SimpleOrderBookEntry{100, 5};
    uint32_t key = 42;

    bool inserted = ht.insert(key, ob);
    assert(inserted && "Insert failed");

    SimpleOrderBookEntry* result = nullptr;
    bool found = ht.lookup(key, reinterpret_cast<void**>(&result));
    assert(found && "Lookup failed");
    assert(result == ob);
    std::cout << "test_insert_and_lookup passed\n";

    delete ob;
}

void test_remove() {
    HashTable ht;

    SimpleOrderBookEntry* ob = new SimpleOrderBookEntry{200, 10};
    uint32_t key = 84;

    ht.insert(key, ob);
    bool removed = ht.erase(key);
    assert(removed && "Remove failed");

    void* result = nullptr;
    bool found = ht.lookup(key, &result);
    assert(!found && "Lookup should have failed after removal");
    std::cout << "test_remove passed\n";

    delete ob;
}

void test_collision() {
    HashTable ht;

    uint32_t key1 = 0x1A2B3C00;
    uint32_t key2 = 0x2A2B3C00; // causes collision in low bits
    auto* a = new SimpleOrderBookEntry{111, 1};
    auto* b = new SimpleOrderBookEntry{222, 2};

    ht.insert(key1, a);
    ht.insert(key2, b);

    SimpleOrderBookEntry* out1 = nullptr;
    SimpleOrderBookEntry* out2 = nullptr;

    assert(ht.lookup(key1, reinterpret_cast<void**>(&out1)));
    assert(ht.lookup(key2, reinterpret_cast<void**>(&out2)));
    assert(out1 == a);
    assert(out2 == b);

    std::cout << "test_collision passed\n";

    delete a;
    delete b;
}

void test_overwrite() {
    HashTable ht;

    uint32_t key = 1000;
    auto* a = new SimpleOrderBookEntry{111, 1};
    auto* b = new SimpleOrderBookEntry{222, 2};

    ht.insert(key, a);
    ht.insert(key, b);

    SimpleOrderBookEntry* out = nullptr;

    assert(ht.lookup(key, reinterpret_cast<void**>(&out)));
    assert(out == b);

    assert(ht.erase(key));
    assert(!ht.lookup(key, reinterpret_cast<void**>(&out)));

    std::cout << "test_overwrite passed\n";

    delete a;
    delete b;
}

int main() {
    test_insert_and_lookup();
    test_remove();
    test_collision();
    test_overwrite();
    std::cout << "All tests passed.\n";
    return 0;
}

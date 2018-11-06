- Feature Name: binary-heaps
- Start Date: 2018-11-02
- RFC PR:
- Pony Issue:

# Summary

This RFC proposes the addition of Priority queues to the collections package of
the standard library. This will include a min-heap and a max-heap implemented
as binary heaps stored as an array.

# Motivation

Binary heaps are a useful data structure for processing items based on priority.
Priority queue implementations based on binary heaps exsist in the standard
libraries of other languages such as the max-heap in
[Rust](https://doc.rust-lang.org/std/collections/struct.BinaryHeap.html)
and the min-heap in
[Go](https://golang.org/pkg/container/heap/).
The choice of default ordering seems a bit arbitrary, so this RFC will
include both `MinHeap` and `MaxHeap` as specializations of a generic
`BinaryHeap` type.

An existing implementation of this may be found at
[theodus/pony-heap](https://github.com/Theodus/pony-heap).

# Detailed design

The API and documentation for the `BinaryHeap` class will be as follows:

```pony
class BinaryHeap[A: Comparable[A] #read, P: BinaryHeapPriority[A]]
  """
  A priority queue implemented as a binary heap. The `BinaryHeapPriority` type
  parameter determines whether this is max-heap or a min-heap.
  """

  new create(len: USize) =>
    """
    Create an empty heap with space for `len` elements.
    """

  fun ref clear() =>
    """
    Remove all elements from the heap.
    """

  fun size(): USize =>
    """
    Return the number of elements in the heap.
    """

  fun peek(): this->A ? =>
    """
    Return the highest priority item in the heap. For max-heaps, the greatest
    item will be returned. For min-heaps, the smallest item will be returned.
    """

  fun ref push(value: A) =>
    """
    Push an item into the heap.

    The time complexity of this operation is O(log(n)) with respect to the size
    of the heap.
    """

  fun ref pop(): A^ ? =>
    """
    Remove the highest priority value from the heap and return it. For
    max-heaps, the greatest item will be returned. For min-heaps, the smallest
    item will be returned.

    The time complexity of this operation is O(log(n)) with respect to the size
    of the heap.
    """

  fun ref append(
    seq: (ReadSeq[A] & ReadElement[A^]),
    offset: USize = 0,
    len: USize = -1)
  =>
    """
    Append len elements from a sequence, starting from the given offset.
    """

  fun ref concat(iter: Iterator[A^], offset: USize = 0, len: USize = -1) =>
    """
    Add len iterated elements, starting from the given offset.
    """

  fun values(): ArrayValues[A, this->Array[A]]^ =>
    """
    Return an iterator for the elements in the heap. The order of elements is
    arbitrary.
    """
```

The other associated types will be defined as follows:

```pony
type MinHeap[A: Comparable[A] #read] is BinaryHeap[A, MinHeapPriority[A]]

type MaxHeap[A: Comparable[A] #read] is BinaryHeap[A, MaxHeapPriority[A]]

type BinaryHeapPriority[A: Comparable[A] #read] is
  ( _BinaryHeapPriority[A]
  & (MinHeapPriority[A] | MaxHeapPriority[A]))

interface val _BinaryHeapPriority[A: Comparable[A] #read]
  new val create()
  fun apply(x: A, y: A): Bool

primitive MinHeapPriority[A: Comparable[A] #read] is _BinaryHeapPriority[A]
  fun apply(x: A, y: A): Bool =>
    x < y

primitive MaxHeapPriority [A: Comparable[A] #read] is _BinaryHeapPriority[A]
  fun apply(x: A, y: A): Bool =>
    x > y
```

# How We Teach This

The documentation above will be included for the `BinaryHeap` class and for all
of its public functions.

# How We Test This

The existing implementation includes generative unit tests for the `push`,
`pop`, and `update` operations. These tests will be added to the existing unit
tests for the collections package.

# Drawbacks

* Additional code will be added to the collections package of the standard
library.

# Alternatives

Alternative heap implementations exist which have better amoritized time
complexities, such as the fibonacci heap. However these data structures are not
as efficient in practice since binary heaps can be easily stored as a single
array.

# Unresolved questions

* Should the API expose other `Seq` functions, such as apply, delete, shift,
etc.?

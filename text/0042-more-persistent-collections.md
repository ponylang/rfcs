- Feature Name: more-persistent-collections
- Start Date: 2017-03-30
- RFC PR: https://github.com/ponylang/rfcs/pull/88
- Pony Issue: https://github.com/ponylang/ponyc/issues/1884

# Summary

This RFC proposes the addition of two persistent data structures to the standard library, Set and Vec.

# Motivation

The goal of this RFC is to provide persistent data structures for use cases that are not fulfilled by the persistent List or Map.

# Detailed design

The Set class will be implemented using the persistent Map and will have the following API:

```pony

type Set[A: (Hashable val & Equatable[A])] is HashSet[A, HashEq[A]]

type SetIs[A: Any #share] is HashSet[A, HashIs[A]]

class val HashSet[A: Any #share, H: HashFunction[A] val] is Comparable[HashSet[A, H] box]
    """
    A set, built on top of persistent Map. This is implemented as map of an alias of a type to itself.
    """

    fun val size(): USize
        """
        Return the number of elements in the set.
        """

    fun val apply(value: val->A): val->A ?
        """
        Return the value if it is in the set, otherwise raise an error.
        """

    fun val contains(value: val->A): Bool
        """
        Check whether the set contains the value.
        """

    fun val add(value: val->A): HashSet[A, H]
        """
        Return a set with the value added.
        """

    fun val sub(value: val->A): HashSet[A, H]
        """
        Return a set with the value removed.
        """

    fun val op_or(that: (HashSet[A, H] | Iterator[A])): HashSet[A, H]
        """
        Return a set with the elements of both this and that.
        """

    fun val op_and(that: (HashSet[A, H] | Iterator[A])): HashSet[A, H]
        """
        Return a set with the elements that are in both this and that.
        """

    fun val op_xor(that: (HashSet[A, H] | Iterator[A])): HashSet[A, H]
        """
        Return a set with elements that are in either this or that, but not both.
        """

    fun val without(that: (HashSet[A, H] | Iterator[A])): HashSet[A, H]
        """
        Return a set with the elements of this that are not in that.
        """

    fun val eq(that: HashSet[A, H]): Bool
        """
        Return true if this and that contain the same elements.
        """

    fun val ne(that: HashSet[A, H]): Bool
        """
        Return false if this and that contain the same elements.
        """

    fun val lt(that: HashSet[A, H]): Bool
        """
        Return true if every element in this is also in that, and this has fewer elements than that.
        """

    fun val le(that: HashSet[A, H]): Bool
        """
        Return true if every element in this is also in that.
        """

    fun val gt(that: HashSet[A, H]): Bool
        """
        Return true if every element in that is also in this, and this has more elements than that.
        """

    fun val ge(that: HashSet[A, H]): Bool
        """
        Return true if every element in that is also in this.
        """

    fun val values(): Iterator[A]^
        """
        Return an iterator over the values in the set.
        """

```

The Vec class will be implemented as a persistent Hash Array Mapped Trie based on Phil Bagwell's paper [Ideal Hash Trees](http://lampwww.epfl.ch/papers/idealhashtrees.pdf), similar to Clojure's Vector. It will have the following API:

```pony
class val Vec[A: Any #share]
    """
    A persistent vector based on the Hash Array Mapped Trie from 'Ideal Hash Trees' by Phil Bagwell.
    """

    fun val size(): USize
        """
        Return the amount of values in the vector.
        """

    fun val apply(i: USize): val->A ?
        """
        Get the i-th element, raising an error if the index is out of bounds.
        """

    fun val update(i: USize, value: val->A): Vec[A] ?
        """
        Return a vector with the i-th element changed, raising an error if the index is out of bounds.
        """

    fun val insert(i: USize, value: val->A): Vec[A] ?
        """
        Return a vector with an element inserted. Elements after this are moved up by one index, extending the vector. An out of bounds index raises an error.
        """

    fun val delete(i: USize): Vec[A] ?
        """
        Return a vector with an element deleted. Elements after this are moved down by one index, compacting the vector. An out of bounds index raises an error.
        """

    fun val remove(i: USize, n: USize): Vec[A] ?
        """
        Return a vector with n elements removed, beginning at index i.
        """

    fun val push(value: val->A): Vec[A]
        """
        Return a vector with the value added to the end.
        """

    fun val pop(): Vec[A]
        """
        Return a vector with the value at the end removed.
        """

    fun val concat(iter: Iterator[val->A]): Vec[A]
        """
        Return a vector with the values of the given iterator added to the end.
        """

    fun val find(
        value: val->A,
        offset: USize = 0,
        nth: USize = 0,
        predicate: {(A, A): Bool} val = {(l: A, r: A): Bool => l is r })
    : USize ?
        """
        Find the `nth` appearance of `value` from the beginning of the vector, starting at `offset` and examining higher indices, and using the supplied `predicate` for comparisons. Returns the index of the value, or raise an error if the value isn't present.

        By default, the search starts at the first element of the vector, returns the first instance of `value` found, and uses object identity for comparison.
        """

    fun val contains(
        value: val->A,
        predicate: {(A, A): Bool} val = {(l: A, r: A): Bool => l is r })
    : Bool
        """
        Returns true if the vector contains `value`, false otherwise.
        """

    fun val slice(from: USize = 0, to: USize = -1, step: USize = 1): Vec[A]
        """
        Return a vector that is a clone of a portion of this vector. The range is exclusive and saturated.
        """

    fun val reverse(): Vec[A]
        """
        Return a vector with the elements in reverse order.
        """

    fun val keys(): Iterator[USize]
        """
        Return an iterator over the indices in the vector.
        """
    
    fun val values(): Iterator[A]
        """
        Return an iterator over the values in the vector.
        """
    
    fun val pairs(): Iterator[A]
        """
        Return an iterator over the (index, value) pairs in the vector.
        """

```

# How We Teach This

The documentation included should be sufficient as the APIs resemble those of existing data structures.

# How We Test This

Each data structure will have unit tests for its methods to ensure that they work as expected.

# Drawbacks

These added classes will increase the maintenance cost of the standard library.

# Unresolved questions

None

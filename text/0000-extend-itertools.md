- Feature Name: Extend tertools
- Start Date: 2016-09-01
- RFC PR: 
- Pony Issue: 

# Summary

The itertools package of the standard library may be extended to provide useful classes and primitives for performing transformations on collections through the use of iterators. But before we implement the equivalent of [Rust's Iterator](https://doc.rust-lang.org/std/iter/trait.Iterator.html) or [Elixir's Enum](http://elixir-lang.org/docs/stable/elixir/Enum.html), we should come to a consensus on whether to add these features to itertools, as an extension to the Seq interface, or as an extension to the Iterator interface.

# Motivation

The goal of this RFC is to implement various data transformations such as map, filter, reduce, etc., now and with more to come, without re-implementing for every collection.

# Detailed design

1. Add the following to the itertools package:
  ```pony
  class Enum[A, B: (Real[B] val & Number) = USize] is Iterator[(B, A)]
    """
    An iterator which yields the current iteration count as well as the next value
    from the given iterator.
    """
  
  primitive Fold[A, B]
    """
    Apply a function to every element, producing an accumulated value.
    """
    fun apply(iter: Iterator[A], f: {(B, A!): B^ ?} box, acc: B): B^ ?
  ```

2. Remove the map, filter, and fold methods of the List and persistent/List collections with the intention of removing other methods in the future when they are implemented in itertools (such as flat_map).

3. Remove any iterators that include ordered indices, such as `ArrayKeys` (which may be replaced by `Range(0, Array.size())`) and `ArrayPairs` (which may be replaced by `Enum(Array.values())`)

# How We Teach This

The current documentation in the itertools package will serve as the template for documenting classes added to the package.

# Drawbacks

This will break existing code.

# Alternatives

Add similar functionality to the Seq or Iterator interface

# Unresolved questions

None

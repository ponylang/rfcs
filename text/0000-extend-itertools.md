- Feature Name: Extend tertools
- Start Date: 2016-09-01
- RFC PR: 
- Pony Issue: 

# Summary

The itertools package of the standard library may be extended to provide useful classes and primitives for performing transformations on collections through the use of iterators. The package may eventually be extended to the equivalent of [Rust's Iterator](https://doc.rust-lang.org/std/iter/trait.Iterator.html) or [Elixir's Enum](http://elixir-lang.org/docs/stable/elixir/Enum.html).

# Motivation

The goal of this RFC is to implement various data transformations such as map, filter, reduce, etc., now and with more to come, without re-implementing for every collection.

# Detailed design

1. Move the functionality of the primitives in itertools to a single wrapper class:
  
  ```pony
  class Iter[A] is Iterator[A]
    new create(iter: Iterator[A])
  ```
2. Add `enum` and `fold` methods to the class
  ```pony
  fun enum[B: (Real[B] val & Number) = USize]: Iter[A]^
    """
    An iterator which yields the current iteration count as well as the next value
    from the iterator.
    """
  
  fun fold[B](f: {(B, A!): B^ ?} box, acc: B): B^ ?
    """
    Apply a function to every element, producing an accumulated value.
    """
  ```

3. Remove the map, filter, and fold methods of the List and persistent/List collections with the intention of removing other methods in the future when they are implemented in itertools (such as flat_map).

4. Remove any iterators that include ordered indices, such as `ArrayKeys` (which may be replaced by `Range(0, Array.size())`) and `ArrayPairs` (which may be replaced by `Iter[A](Array.values()).enum()`)

# How We Teach This

The current documentation in the itertools package will serve as the template for documenting classes added to the package.

# Drawbacks

This will break existing code.

# Alternatives

Add similar functionality to the Seq or Iterator interface directly

# Unresolved questions

None

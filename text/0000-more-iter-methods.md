- Feature Name: more-iter-methods
- Start Date: 2016-10-16
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

This RFC proposes the addition of various methods to the Iter class of the itertools package. The methods included are based on functions from [Rust's Iterator](https://doc.rust-lang.org/std/iter/trait.Iterator.html) and [Elixir's Enum](http://elixir-lang.org/docs/stable/elixir/Enum.html).

# Motivation

The purpose of these additional methods is to increase the functionality of the Iter class.

# Detailed design

The following methods will be added to the Iter class:
```pony
fun ref all(f: {(A!): Bool ?} box): Bool =>
    """
    Return false if at least one value of the iterator fails to match the
    predicate `f`. This method short-circuits at the first value where the
    predicate returns false, otherwise true is returned.
    """

fun ref any(f: {(A!): Bool ?} box): Bool =>
    """
    Return true if at least one value of the iterator matches the predicate `f`.
    This method short-circuits at the first value where the predicate returns
    true, otherwise false is returned.
    """

fun ref collect[B: Seq[A!] = Array[A!]](coll: B): B^ =>
    """
    Push each value from the iterator into the collection `coll`.
    """

fun ref count(): USize =>
    """
    Return the number of values in the iterator.
    """

fun ref find(f: {(A!): Bool ?} box, n: USize = 1): A ? =>
    """
    Return the nth value in the iterator that satisfies the predicate `f`.
    """

fun ref last(): A ? =>
    """
    Return the last value of the iterator.
    """

fun ref nth(n: USize): A ? =>
    """
    Return the nth value of the iterator.
    """

fun ref run(on_error: {()} box = lambda() => None end) =>
    """
    Iterate through the values of the iterator without a for loop. The
    function `on_error` will be called if the iterator's `has_next` method
    returns true but its `next` method trows an error. 
    """

fun ref skip(n: USize): Iter[A]^ =>
    """
    Skip the first n values of the iterator.
    """

fun ref skip_while(f: {(A!): Bool ?} box): Iter[A]^ =>
    """
    Skip values of the iterator while the predicate `f` returns true.
    """

fun ref take(n: USize): Iter[A]^ =>
    """
    Return an iterator for the first n elements.
    """

fun ref take_while(f: {(A!): Bool ?} box): Iter[A]^ =>
    """
    Return an iterator that returns values while the predicate `f` returns true.
    """

```

# How We Teach This

The added methods must be properly documented and the top level package documentation of itertools should be updated to include the Iter class.

# How We Test This

Every method added must have a unit test to ensure that it works as expected. This includes testing for cases that may not behave as intended such as iterators with no values or predicates that may throw errors.

# Drawbacks

The additional code will add a slight maintenance cost.

# Alternatives

Other methods may be added in addition or as replacements to the ones described above.

# Unresolved questions

Are there other methods that should be considered?

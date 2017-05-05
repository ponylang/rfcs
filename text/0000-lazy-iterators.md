- Feature Name: lazy-iterators
- Start Date: 2017-01-02
- RFC PR: 
- Pony Issue: 

# Summary

This RFC proposes the extension of the current Iterator interface so that it provides the functions of the itertools/Iter class. This will allow for a single point of implementation for data transformations that make use of lazy evaluation for improved performance of multiple transformations.

# Motivation

This change is motivated by the convenience and performance of [Rust's lazy iterators](https://doc.rust-lang.org/std/iter/index.html). This change will provide the functionality within the itertools package without having to wrap an existing Iterator.

# Detailed design

These changes require that the current Iterator interface is changed to a trait which maintains the `has_next()` and `next()` methods and provides the following additional methods with default implementations:

```pony
  fun ref all(f: {(A!): Bool ?} box): Bool =>
    """
    Return false if at least one value of the iterator fails to match the
    predicate `f`. This method short-circuits at the first value where the
    predicate returns false, otherwise true is returned.
    ## Examples
    ```pony
    [as I64: 2, 4, 6].values()
      .all({(x: I64): Bool => (x % 2) == 0})
    ```
    `true`
    ```pony
    [as I64: 2, 3, 4].values()
      .all({(x: I64): Bool => (x % 2) == 0})
    ```
    `false`
    """

  fun ref any(f: {(A!): Bool ?} box): Bool =>
    """
    Return true if at least one value of the iterator matches the predicate 
    `f`. This method short-circuits at the first value where the predicate
    returns true, otherwise false is returned.
    ## Examples
    ```pony
    [as I64: 2, 4, 6].values()
      .any({(x: I64): Bool => (x % 2) == 1})
    ```
    `false`
    ```pony
    [as I64: 2, 3, 4].values()
      .any({(x: I64): Bool => (x % 2) == 1})
    ```
    `true`
    """

  fun ref chain(iter: Iterator[A]): Iterator[A] =>
    """
    Return an iterator that first iterates over values of the first iterator
    and then over the values of the second iterator.

    ##Example
    ```pony
    let iter1 = [as I64: 1, 2, 3].values()
    let iter2 = [as I64: 4, 5, 6].values()
    iter1.chain(iter2)
    ```
    `1 2 3 4 5 6`
    """

  fun ref collect[B: Seq[A!] = Array[A!]](coll: B): B^ =>
    """
    Push each value from the iterator into the collection `coll`.
    ## Example
    ```pony
    [as I64: 1, 2, 3].values()
      .collect(Array[I64](3))
    ```
    `[1, 2, 3]`
    """
    for x in this do
      coll.push(x)
    end
    coll

  fun ref count(): USize =>
    """
    Return the number of values in the iterator.
    ## Example
    ```pony
    [as I64: 1, 2, 3].values()
      .count()
    ```
    `3`
    """

  fun ref cycle(): Iterator[A!]^ =>
    """
    Repeatedly cycle through the values from the iterator.
    ## Example
    ```pony
    [as I64: 1, 2, 3].values()
      .cycle()
    ```
    `1 2 3 1 2 3 1 2 3 ...`
    """

  fun ref enum[B: (Real[B] val & Number) = USize](): Iterator[(B, A)]^ =>
    """
    An iterator which yields the current iteration count as well as the next
    value from the iterator.
    ## Example
    ```pony
    [as I64: 1, 2, 3].values()
      .enum()
    ```
    `(0, 1) (1, 2) (2, 3)`
    """

  fun ref filter(f: {(A!): Bool ?} box): Iterator[A]^ =>
    """
    Return an iterator that only returns items that match the predicate `f`.
    
    ## Example
    ```pony
    [as I64: 1, 2, 3, 4, 5, 6].values()
      .filter({(x: I64): Bool => (x % 2) == 0})
    ```
    `2 4 6`
    """

  fun ref find(f: {(A!): Bool ?} box, n: USize = 1): A ? =>
    """
    Return the nth value in the iterator that satisfies the predicate `f`.
    
    ## Examples
    ```pony
    [as I64: 1, 2, 3].values()
      .find({(x: I64): Bool => (x % 2) == 0})
    ```
    `2`
    ```pony
    [as I64: 1, 2, 3, 4].values()
      .find({(x: I64): Bool => (x % 2) == 0}, 2)
    ```
    `4`
    """

  fun ref flat_map[B](f: {(A!): Iterator[B] ?} box): Iterator[B] =>
    """
    Return an iterator that works like map, but flattens the nested structure
	returned by the function.
	
    ## Example
    ```pony
    ["cat", "dog", "ferret"].values()
      .flat_map[U8]({(word: String): Iterator[U8] => word.values()})
    ```
    `c a t d o g f e r r e t`
    """

  fun ref fold[B](acc: B, f: {(B, A!): B^ ?} box): B^ ? =>
    """
    Apply a function to every element, producing an accumulated value.
    
    ## Example
    ```pony
    [as I64: 1, 2, 3].values()
      .fold[I64](0, {(x: I64, sum: I64): I64 => sum + x})
    ```
    `6`
    """

  fun ref last(): A ? =>
    """
    Return the last value of the iterator.
    ## Example
    ```pony
    [as I64: 1, 2, 3].values()
      .last()
    ```
    `3`
    """

  fun ref map[B](f: {(A!): B ?} box): Iterator[B]^ ? =>
    """
    Return an iterator where each item's value is the application of the given
    function to the value in the original iterator.
    
    ## Example
    ```pony
    [as I64: 1, 2, 3].values()
      .map[I64]({(x: I64): I64 => x * x})
    ```
    `1 4 9`
    """

  fun ref nth(n: USize): A ? =>
    """
    Return the nth value of the iterator (zero-based).
    ## Example
    ```pony
    [as I64: 1, 2, 3].values()
      .nth(1)
    ```
    `2`
    """

  fun ref run(on_error: ({()} box | None) = None) =>
    """
    Iterate through the values of the iterator without a for loop. The
    function `on_error` will be called if the iterator's `has_next` method
    returns true but its `next` method trows an error.
    ## Example
    ```pony
    [as I64: 1, 2, 3].values()
      .map[None]({(x: I64)(env) => env.out.print(x.string())})
      .run()
    ```
    ```
    1
    2
    3
    ```
    """

  fun ref skip(n: USize): Iterator[A]^ =>
    """
    Skip the first n values of the iterator.
    ## Example
    ```pony
    [as I64: 1, 2, 3, 4, 5, 6].values()
      .skip(3)
    ```
    `4 5 6`
    """

  fun ref skip_while(f: {(A!): Bool ?} box): Iterator[A]^ =>
    """
    Skip values of the iterator while the predicate `f` returns true.
    
    ## Example
    ```pony
    [as I64: 1, 2, 3, 4, 5, 6].values()
      .skip_while({(x: I64): Bool => x < 4})
    ```
    `4 5 6`
    """

  fun ref take(n: USize): Iterator[A]^ =>
    """
    Return an iterator for the first n elements.
    ## Example
    ```pony
    [as I64: 1, 2, 3, 4, 5, 6].values()
      .take(3)
    ```
    `1 2 3`
    """

  fun ref take_while(f: {(A!): Bool ?} box): Iterator[A]^ =>
    """
    Return an iterator that returns values while the predicate `f` returns
    true.
    ## Example
    ```pony
    [as I64: 1, 2, 3, 4, 5, 6].values()
      .take_while({(x: I64): Bool => x < 4})
    ```
    `1 2 3`
    """

  fun ref zip[B](iter: Iterator[B]): Iterator[(A, B)]^ =>
	"""
    Zip two iterators together so that each call to next() results in the
    a tuple with the next value of the first iterator and the next value
    of the second iterator. The number of items returned is the minimum of
    the number of items returned by the two iterators.
    ## Example
    ```pony
    [as I64: 1, 2].values()
      .zip[I64]([as I64: 3, 4].values())
    ```
    `(1, 3) (2, 4)`
    """
```

The itertools package of the standard library will also be removed.

The following types that implement Iterator will now need to state it explicitly:
- collections/ListNode
- collections/persistent/MapKeys, MapValues, and MapPairs
- random/Random

# How We Teach This

The above documentation including examples will be given for all methods added to Iterator. Trait-level documentation will resemble the package-level documentation of the itertools package in order to explain laziness.

# How We Test This

Every method added must have a unit test to ensure that it works as expected as in the itertools package. This includes testing for cases that may not behave as intended such as iterators with no values or predicates that may throw errors.

# Drawbacks

- Addition of code to builtin
- Breaks any code that implements the Iterator interface without stating `is Interface[..]`

# Alternatives

- Continue with the separate itertools package and Iterator interface

# Unresolved questions

- Should methods such as map and fold allow partial functions as arguments making them partial? Should there be partial equivalents such as map_partial and fold_partial?

- Feature Name: improved-itertools-api
- Start Date: 2017-08-8
- RFC PR: 
- Pony Issue: 

# Summary

The goal of this RFC is to improve the usability and reduce the maintenance cost of the itertools package.

# Motivation

The motivation for this RFC comes from concerns that I have gathered from my own experiences and from the concerns and recommendations of members of the Pony community. The primary concern that I have heard is inconvenience caused by `fold` being partial. Also, adapting iterators with any state is impossible since the arguments to methods such as `map` and `filter` are lambdas with a capability of box. This lack of stateful adaptations also has the side effect of making the `Iter` class prone to code duplication to handle common tasks like stashing values in order to maintain the semantics of filtering. With the addition of methods like `flat_map` and `filter_map`, the problem of code duplication becomes a more noticeable issue for future additions to the API.

# Detailed design

The fold method will be modified so that its argument may not be partial. The arguments have also been reordered to improve the ergonomics of partial application.

```pony
fun ref fold[B](acc: B, f: {(B, A!): B^} box): B^
```

A partial version of the method will be provided as well.

```pony
fun ref fold_partial[B](acc: B, f: {(B, A!): B^ ?} box): B^ ?
  """
  A partial version of `fold`.
  """
```

The `run` method signature will also have its lambda argument changed to the following:
```
fun ref run(on_error: {ref()} = {() => None } ref)
```

The following methods and constructors will be added to the Iter class:

```pony
new repeat_value(value: A)
  """
  Create an iterator that returns the given value forever.

  ## Example

  Iter[U32].repeat_value(7)

  `7 7 7 7 7 7 7 7 7 ...`
  """

fun ref map_stateful[B](f: {(A!): B ?} ref): Iter[B]^
  """
  Allows stateful transformaion of each element from the iterator, similar
  to `map`.
  """

fun ref filter_stateful(f: {(A!): Bool ?} ref): Iter[A]^
  """
  Allows filtering of elements based on a stateful adapter, similar to
  `filter`.
  """

fun ref filter_map_stateful[B](f: {(A!): (B | None) ?} ref): Iter[B]^
  """
  Allows stateful modification to the stream of elements from an iterator,
  similar to `filter_map`.
  """

fun ref filter_map[B](f: {(A!): (B | None) ?} box): Iter[B]^
  """
  Return an iterator which applies `f` to each element. If `None` is
  returned, then the iterator will try again by applying `f` to the next
  element. Otherwise, the value of type `B` is returned.

  ## Example

  Iter[I64]([as I64: 1; -2; 4; 7; -5])
    .filter_map[USize](
      {(i: I64): (USize | None) => if i >= 0 then i.usize() end })

  `1 4 7`
  """

fun ref flat_map[B](f: {(A!): Iterator[B] ?} box): Iter[B]^
  """
  Return an iterator over the values of the iterators produced from the
  application of the given function.

  ## Example

  Iter[String](["alpha"; "beta"; "gamma"])
    .flat_map[U8]({(s: String): Iterator[U8] => s.values() })

  `a l p h a b e t a g a m m a`
  """
```

The `Chain`, `Cycle`, `Filter`, `MapFn`, `Repeat`, `Take`, and `Zip2`, `Zip3`, `Zip4`, and `Zip5` classes will be removed from itertools in favor of their equivalent `Iter` methods.

# How We Teach This

The added methods will include documentation as shown above.

# How We Test This

Every method added to the `Iter` class will have a unit test to ensure that it works as expected.

# Drawbacks

This will break existing code that uses the current `fold` and `run` methods.

# Alternatives

# Unresolved questions

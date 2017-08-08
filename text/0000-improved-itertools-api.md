- Feature Name: improved-itertools-api
- Start Date: 2017-08-8
- RFC PR: 
- Pony Issue: 

# Summary

The goal of this RFC is to improve the usability and reduce the maintenance cost of the itertools package.

# Motivation

The motivation for this RFC comes from concerns that I have gathered from my own experiences and from the concerns and recommendations of members of the Pony community. The primary concern that I have heard is inconvenience caused by `fold` being partial. Also, adapting iterators with any state is impossible since the arguments to methods such as `map` and `filter` are lambdas, which means that their `apply` methods have a capability of box. This lack of stateful adaptations also has the side effect of making the `Iter` class prone to code duplication to handle common tasks like stashing values in order to maintain the semantics of filtering. With the addition of methods like `flat_map` and `filter_map`, the problem of code duplication becomes a more noticeable issue for future additions to the API.

# Detailed design

The fold method will be modified so that its argument may not be partial.

```pony
fun ref fold[B](f: {(B, A!): B^} box, acc: B): B^
```

A partial version of the method will be provided as well.

```pony
fun ref fold_partial[B](f: {(B, A!): B^ ?} box, acc: B): B^ ?
  """
  A partial version of `fold`.
  """
```

The following "iterator adapter" interfaces will be added to the package along with corresponding methods of the `Iter` class. These interfaces will facilitate stateful modification to the output of the iterator.

```pony
interface IterMapAdapter[A, B]
  fun ref apply(a: A!): B ?

interface IterFilterAdapter[A]
  fun ref apply(a: A!): Bool ?

interface IterFilterMapAdapter[A, B]
  fun ref apply(a: A!): (B | None) ?
```

```pony
fun ref map_adapter[B](adapter: IterMapAdapter[A, B]): Iter[B]^
  """
  Allows stateful transformaion of each element from the iterator, similar
  to `map`.
  """

fun ref filter_adapter(adapter: IterFilterAdapter[A]): Iter[A!]^
  """
  Allows filtering of elements based on a stateful adapter, similar to
  `filter`.
  """

fun ref filter_map_adapter[B](adapter: IterFilterMapAdapter[A, B]): Iter[B]^
  """
  Allows stateful modification to the stream of elements from an iterator,
  similar to `filter_map`.
  """
```

Many of the existing methods will be re-implemented using these three methods in order to reduce the probability of logical errors related to coordination between the `has_next` and `next` methods to stash the next value of the iterator. Because of this, the return types of some methods will change from `Iter[A]` to `Iter[A!]`. A notable example is the `enum` method, where the return type was previously `Iter[(B, A)]^`:

```pony
fun ref enum[B: (Real[B] val & Number) = USize](): Iter[(B, A!)]^
```

The following methods will be added to the Iter class:

```pony
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

# How We Teach This

The added methods will include documentation as shown above.

# How We Test This

Every method added to the `Iter` class will have a unit test to ensure that it works as expected.

# Drawbacks

This will break existing code that uses the current `fold` method. Also, the minor change in return type will break any code that attempts to access a val field from the return value of an `Iter` of some iso type. It should be noted that this will have no effect on any `Iter` of some iso^ type since `A^! -> A`.

# Alternatives

We may choose not to include the iterator adapters if the change in return type is not worth reducing the maintenance cost of the itertools package.

# Unresolved questions

- Should the `acc` argument to `fold` and `fold_partial` be the first argument? How may this affect partial application?
- Should we keep the classes such as `MapFn` and `Take`? Users may be confused by some methods of the `Iter` class having external implementations while most do not.

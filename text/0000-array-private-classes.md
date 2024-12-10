- Feature Name: array_private_classes
- Start Date: 2022-01-08
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

Rendered RFC: https://github.com/pmetras/rfcs/blob/rfc-array/text/0000-array-private-classes.md

# Summary

Collection classes should not expose internal classes through iterators functions.

Following information hiding design principle, the builtin classes of collection
data structures must not be made visible through iterator functions like `ArrayKeys`,
`ArrayValues` and `ArrayPairs`. These classes can be made private as they are
only used as return types for `Array` functions `keys`, `values` and `pairs`.
The return values for these functions are changed to the more general interface
`Iterator`.

A new interface `CollectionIterator` is defined to allow for rewindable iterators,
like it is the case for `Array` `values`.

This design principle is applied to the other collection classes that expose
internals too like:

* `List`
* `Map`
* persistent `Map`
* `Vec`
* persistent `Vec`
* `Set`
* `Itertools`

This is a breaking change for collections' client code that use now internal
classes but a search on Github repositories shows that the impact should be
limited.

# Motivation

This change brings:

- Applying the design principle of
[hiding implementation details](https://en.wikipedia.org/wiki/Information_hiding)
but offer a general and stable interface. Returning interfaces instead of concrete
classes allows changing the implementation. Usually, one must return the most
general type that fullfils the contract of the function (in the case of the
functions discussed in this RFC, iteration).
- Collections' functions `keys`, `values` and `pairs` definitions are made more
general. Iterators implementation details are not public. Internal classes used
by implementation like `*Keys`, `*Values` and `*Pairs` are now
[opaque data types](https://en.wikipedia.org/wiki/Opaque_data_type). Generally,
when using these collection classes, clients are not interested by the iterators
implementation, but by the types these iterators return and that is provided by
the generic parameters.
- The generic return signature of these 3 iterating functions is simpler to
understand for clients of collection classes.
- Reduces the number of public classes in the standard library by hiding 18
specialised classes (iterators implementations) of which 3 are from the
`builtin` module.
- The interface `CollectionIterator` is added to create rewindable iterators
(can be re-start from first value).

This change remains compatible with the existing code base but for client code
that is directly using the classes `*Keys`, `*Values` and `*Pairs`. A search on
Github shows that the impact is very limited.

To quote Antoine de Saint-Exupéry:

> Perfection is achieved, not when there is nothing more to add, but when there
> is nothing left to take away.

Currently the API makes a guarantee that the return value of each of these functions
is a specific concrete class with a specific public name. That particular guarantee
does not actually serve any practical needs of users (except, arguably, the virtual
calls caveat that was mentioned on [Github discussion](https://github.com/ponylang/rfcs/pull/193#issuecomment-1009733064)). If it is not helpful to users in practice,
it can be removed. And if it can be removed, then it should be removed, in the
name of taking another step toward stabilizing the Pony standard library's API.

It's worth mentioning that if this change was being debated in reverse (the
current standard library had minimal interfaces for the return values, and
somebody proposed to make them public concrete classes instead, because they
found some tangible benefit in doing so), then it would not be a breaking change
at all, because the new proposed type would be a subtype of the existing return
types.

It'll always be easier to get more specific with these return types than more
general. So we should default to offering the most general return type that is
still useful to users, and ratchet down to more specific subtypes as needed (as
tangible use cases for more specific return types are discovered). Ratcheting down
will always be possible without a breaking change, but ratcheting up will be a
breaking change each time. It's best to make such "ratchet up" breaking changes
like this RFC before we reach Pony 1.0.0 as part of a general effort to make Pony
and its standard library stable.

# Detailed design

Iterating functions in collections `keys`, `values` and `pairs` are changed to
return `Iterator` and the classes that implement these iterators are made private.
Here are the full implementation of these functions for the `Array` class (changes
in other collection classes are identical).

As the function `values` of class `Array` uses an iterator with a `rewind` function
that is not part of the `Iterator` interface, a new interface `CollectionIterator`
is added to enable creation of rewindable iterators.

```pony
  fun keys(): CollectionIterator[USize]^ =>
    """
    Return an iterator over the indices in the array.
    """
    _ArrayKeys[A, this->Array[A]](this)

  fun values(): CollectionIterator[this->A]^ =>
    """
    Return an iterator over the values in the array.
    """
    _ArrayValues[A, this->Array[A]](this)

  fun pairs(): CollectionIterator[(USize, this->A)]^ =>
    """
    Return an iterator over the (index, value) pairs in the array.
    """
    _ArrayPairs[A, this->Array[A]](this)
```

Note: To remain consistent with `Array` behaviour, functions `keys` and `pairs`
will return a `CollectionIterator`.

```pony
interface CollectionIterator[A] is Iterator[A]
  """
  A `CollectionIterator` is an iterator that can be rewinded, that is start
  again from first item. The data structure being iterated on can't change the
  order it return iterated items.
  """
  fun has_next(): Bool
    """
    Return `true` when function `next` can be called to get next iteration item.
    """

  fun ref next(): A ?
    """
    Return the next item of the iteration or an error in case there are no other
    items. A previous call to `has_next` check if we can continue iteration.
    """

  fun ref rewind(): Iterator[A]^
    """
    Start the iterator over again from the beginning.
    """
```

The code of the standard library is adapted to remove use of these now private
classes, mainly in tests. Here are the files that must be changed:

* `packages/builtin/array.pony` as shown above
* `packages/itertools/iter.pony` in function `cycle`
* `packages/collections/heap.pony` in function `values`
* `packages/collection/builtin/_test.pony` in class `_TestArrayValuesRewind`
* `packages/collections/list.pony`
* `packages/collections/map.pony`
* `packages/collections/persistent/map.pony`
* `packages/collections/persistent/vec.pony`
* `packages/collections/set.pony`
* `test/libponyc/util.cc` to change the name of the class to `_ArrayValues`

## Detailed changes

In order to judge how the API becomes simpler to understand for clients of the
collections classes, here are the changes in the functions' signatures. The `-`
line shows the old signature while the `+` one is the new:

```pony
// Array
-  fun keys(): ArrayKeys[A, this->Array[A]]^ =>
+  fun keys(): Iterator[USize]^ =>
-  fun values(): ArrayValues[A, this->Array[A]]^ =>
+  fun values(): CollectionIterator[this->A]^ =>
-  fun pairs(): ArrayPairs[A, this->Array[A]]^ =>
+  fun pairs(): Iterator[(USize, this->A)]^ =>

// Heap
-  fun values(): ArrayValues[A, this->Array[A]]^ =>
+  fun values(): Iterator[this->A]^ =>

// List
-  fun nodes(): ListNodes[A, this->ListNode[A]]^ =>
+  fun nodes(): Iterator[this->ListNode[A]]^ =>
-  fun rnodes(): ListNodes[A, this->ListNode[A]]^ =>
+  fun rnodes(): Iterator[this->ListNode[A]]^ =>
-  fun values(): ListValues[A, this->ListNode[A]]^ =>
+  fun values(): Iterator[this->A]^ =>
-  fun rvalues(): ListValues[A, this->ListNode[A]]^ =>
+  fun rvalues(): Iterator[this->A]^ =>

// Map
-  fun keys(): MapKeys[K, V, H, this->HashMap[K, V, H]]^ =>
+  fun keys(): Iterator[this->K]^ =>
-  fun values(): MapValues[K, V, H, this->HashMap[K, V, H]]^ =>
+  fun values(): Iterator[this->V]^ =>
-  fun pairs(): MapPairs[K, V, H, this->HashMap[K, V, H]]^ =>
+  fun pairs(): Iterator[(this->K, this->V)]^ =>

// Persistent Map
-  fun val keys(): MapKeys[K, V, H] =>
+  fun val keys(): Iterator[K] =>
-  fun val values(): MapValues[K, V, H] =>
+  fun val values(): Iterator[V] =>
-  fun val pairs(): MapPairs[K, V, H] =>
+  fun val pairs(): Iterator[(K, V)] =>

// Persistent Vec
-  fun val keys(): VecKeys[A]^ =>
+  fun val keys(): Iterator[USize]^ =>
-  fun val values(): VecValues[A]^ =>
+  fun val values(): Iterator[A]^ =>
-  fun val pairs(): VecPairs[A]^ =>
+  fun val pairs(): Iterator[(USize, A)]^ =>

// Set
-  fun values(): SetValues[A, H, this->HashSet[A, H]]^ =>
+  fun values(): Iterator[this->A]^ =>
```

For instance, in `Array`

```pony
-  fun keys(): ArrayKeys[A, this->Array[A]]^ =>
+  fun keys(): Iterator[USize]^ =>
```

now the client user knows now that she gets an iterator over `USize`.

Another more complex example with `Map`,

```pony
-  fun keys(): MapKeys[K, V, H, this->HashMap[K, V, H]]^ =>
+  fun keys(): Iterator[this->K]^ =>
-  fun values(): MapValues[K, V, H, this->HashMap[K, V, H]]^ =>
+  fun values(): Iterator[this->V]^ =>
```

we see that we iterate over keys (`K` type) or values (`V`). The initial signature
gave complex generic classes that the user has to find in the documentation to
understand that they are iterators, and then dive deeper to understand on what
they iterate.

# How We Teach This

This change keeps the code compatible in the vast majority of cases. When client
classes are defining objects of these now private types, the reason is usually
to get access to the function `rewind` that was not defined in `Iterator`. By
adding the interface `CollectionIterator`, client code can easily be adapted,
replacing `ArrayValues[A]` by `CollectionIterator[A]`.

Also, client code generally uses these functions to iterate on the returned types
and does not try to access the iterator directly but is interested by the iterated
items. When client code refers to the iterator type, that's generally useless and
the code can be rewritten to be made shorter and more future proof.

A [search on Github Pony code](https://github.com/search?q=%22ArrayValues%22+language%3APony&type=code)
finds 24 files using the class `ArrayValues`, of which 6 are copies of `array.pony` file.

For instance, in
[xml2xpath.pony](https://github.com/redvers/pony-libxml2/blob/bbca5d98d48854bfec2c6ee110220873ecc4df34/pony-libxml2/xml2xpath.pony#L41),
the code can be changed from

```pony
  fun values(): ArrayValues[Xml2node, this->Array[Xml2node]]^ ? =>
    if (allocated) then
      ArrayValues[Xml2node, this->Array[Xml2node]](nodearray)
    else
      error
    end
```

to

```pony
  fun values(): CollectionIterator[Xml2node]^ ? =>
    if (allocated) then
      nodearray.values()
    else
      error
    end
```

In this sample, the developer was not really concerned by the type of the iterator
but that the `values` function must return an `CollectionIterator` over `Xml2node`.
The new version makes the code simpler to understand.

This change in `array.pony` and other collections will break such code but it
can be easily adapted to use the new API. And it will make the standard library
easier to learn by reducing the number of public types.

# How We Test This

Pony tests must continue to pass. No additional tests are need as after review
the existing coverage in Pony standard library tests is sufficient

# Drawbacks

Will break any existing code that uses any of the classes that are currently
public and will be made private by this RFC.

# Alternatives

1. Stay as is. Continue the
[discussion on Zulip](https://ponylang.zulipchat.com/#narrow/stream/189959-RFCs/topic/Make.20Array.20iterators.20private).

2. Update the existing concrete classes to include `rewind` where needed.

3. Instead of defining a new type of iterator with the `CollectionIterator` interface,
we can consider only the rewindable part of it in an `Rewindable` interface:

```pony
interface Rewindable[A]
  fun ref rewind(): A^
    """
    Rewind the type `A`.
    """
```

Then one can create a rewindable iterator by combining these two interfaces into
a intersection type:

```pony
type CollectionIterator[A] is (Iterator[A] & Rewindable[Iterator[A]])
```

Perhaps, a more general interface name instead of `Rewindable` would be `Resetable`
to define the traits of a type that can be reset to its initial state, as in the
case of iterators `reset` == `rewind`.

The rewindable type can be used with other types than `Iterator`, like a data
structure that would implement a rewindable property. This alternative was
[put aside](https://github.com/ponylang/rfcs/pull/193#discussion_r780793165) to
prevent name colisions in `builtin` with user-named types.

## Comparison of alternatives

1. Do nothing: return public concrete classes.
2. Update the existing return classes and add `rewind`.
3. Add a `CollectionIterator` interface for collections.
4. Create intersection type by defining a `Rewindable` interface and combine
with `Iterator`.
5. Change `Iterator` to add `rewind`.

| Justification        /      Alternative # |  1  |  2  |  3  |  4  |  5  |
|:------------------------------------------|:---:|:---:|:---:|:---:|:---:|
| a. Simpler stdlib API                     | --- | --- |  +  | +++ | +++ |
| b. Simpler function signatures            | --- | --- |  +  | +++ | +++ |
| c. Stay compatible with existing stdlib   | +++ | +++ |  +  | +++ |  +  |
| d. Evolutive                              | --- |  +  | +++ | +++ |  +  |
| e. No impact on compiler                  | +++ | +++ |  -  | +++ |  -  |
| f. No impact on performance               | +++ | +++ | +++ | +++ | +++ |
| g. Limit stdlib pollution with interfaces | +++ | +++ |  +  |  +  | +++ |
| g. Limit stdlib pollution with classes    | --- | --- | +++ | ++  | +++ |

# Unresolved questions

- Must analyze how `Range` and `Reverse` would be impacted if defined as
`CollectionIterator`. Particularly, impact on existing client code.
- Possible candidates to be analyzed: `StringBytes`, `StringRunes`, `ByteSeqIter`
and probably others will be found in stdlib code.
- Understand why the intersection type proposal is not considered as it seems to
provide a better flexibility and is easier to understand.

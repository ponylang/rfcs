- Feature Name: move_hashable_to_builtin
- Start Date: 2019-12-19
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Move `Hashable` to the builtin package and make it easier to make objects `Hashable`
by defining convenience functions that use a common good and fast way of
combining hashes of object fields into a single hash value. Also extend documentation
and tutorial with information on how to make objects hashable.

# Motivation

It is possible to make any object implement the interface `Hashable` or `Hashable64` but
if we want to state that by explicitly extending it we need to add a `use "collections"`,
although we do not intend to use any pony collection:

```pony
use "collections"

class MyClass is Hashable
  fun hash(): USize => 42
```

The main point here is that `Hashable`s main use case is its usage in `HashMap` etc. but
it is not limited to that. The notion of Hashability is generic enough to earn a rank
among other interfaces like `Equatable` which already reside in the `builtin` package.

In fact, there exists a fundamental relationship between `Equatable` and `Hashable`: If
a class `C` is both `Equatable` and `Hashable`, if two instances `c1` and `c2` are considered
equal (as far as structural equality is concerned), their hash should also be the same.

This RFC also suggests to add a primitive called `Hashing` which provides convenience methods for
defining fast and good (enough) `fun hash(): USize` methods for arbitrary objects, combining hashes of the objects fields
with a good hash function ([Siphash-2-4](https://131002.net/siphash/)).

Consider the following example:

```pony

class val MyClass
  let _field1: String
  let _field2: U32

  new val create(f1: String, f2: String) =>
    _field1 = f1
    _field2 = f2
```

To make this class implement `Hashable` or `Hashable64`, we need to find a way to
combine the hashes of both fields if these should make up the identity for this class.
In order to make it more convenient for people to write useful classes
it is favorable to advertise a common way to define hash functions for objects and offer a convenient way
to implement them without too much boilerplate.

This is a cranky, crufty and ugly, hand-crafted hash-function for the class above
(adapted from how most IDEs in java auto-create hashCode methods):

```pony
  fun hash(): USize =>
    var result = USiz(17)
    result = (result * 37) + _field1.hash()
    result = (result * 37) + _field2.hash()
    result
```

A hash function implemented using a convenience function suggested by this RFC
would look as nice and clean as this:

```pony
  fun hash(): USize =>
    Hashing.hash_2(_field1, _field2)
```

# Detailed design

## Move Hashable to Builtin

We move the `Hashable` and `Hashable64` interfaces to the `builtin` package.

## Make hashing objects convenient

A primitive called `Hashing` will be introduced into the `builtin` package, alongside with a pure pony `Siphash` implementation.
Currently libponyrt contains code for hashing byte-sequences with a C-implementation of Siphash
in https://github.com/ponylang/ponyc/blob/master/src/libponyrt/ds/fun.c#L92 . As the implementation is already iterating over
the array in 8-byte (4-byte for 32-bit platforms) increments, we can also use it in a streaming fashion, feeding it consecutive U64.
This way we can feed it hashes of object fields and compute the sip-hash-2-4 of all the hashes of the object fields.

When hashing objects based on their fields, we must take all those fields into account. They might be primitive types, objects with fields themselves,
their hash might be using the fields identiy using the `digestof` operator etc. etc. So generating a hash boils down to a clever way to combine the hashes of all fields
that should be considered. The hashes of the fields are chosen as a common denominator.
And, ideally, those hashes should reflect all of the fields contents. 
So if we build a hash of those hashes using a good enough hash function, we should, by transitivity, also get a good enough hash of the whole object in return.

As far as I know, [SipHash-2-4](https://131002.net/siphash/) can be considered a good enough hash-function.
It is also already in use for byte sequences and strings in Pony.

This `Hashing` primitive will contain methods for hashing `ByteSeqs`, as e.g. `Array[U8]` does not implement `Hashable` but can be easily hashed,
in fact all Arrays of primitive numeric types can and should be very easily hashed.
It will contain methods for hashing `ReadSeq[Hashable #read]` by combining the element hashes into one hash value 
using the [SipHash-2-4](https://131002.net/siphash/) implemention described above.
It will also contain methods for conveniently combining hashes from different objects, like:

```pony

primitive Hashing
  fun hash_3(a: Hashable box, b: Hashable box, c: Hashable box): USize =>
    """
    convenience function for combining the hashes of three object implementing `Hashable`
    into one hash value.
    """
    ifdef ilp32 then
      let sip = HalfSipHash24Streaming.create()
      sip.update(a.hash().u32())
      sip.update(b.hash().u32())
      sip.update(c.hash().u32())
      sip.finish()
    else
      let sip = SipHash24Streaming.create()
      sip.update(a.hash().u64())
      sip.update(b.hash().u64())
      sip.update(c.hash().u64())
      sip.finish()
    end
```

It will contain such functions for 2 arguments up to 12 arguments, maybe more.

# How We Teach This

The Tutorial or the pony patterns (or both) will get a chapter on how to create `value classes`, classes fully represented by their fields.
In other category theory contexts these are also known as Product types.

`value classes` (The actual name we use for these classes is very much up for debate) should implement Hashable using the `Hashing` primitive if possible and Equatable.
Equality should be based upon the same fields used for generating the hash. We should also mention implementing `Comparable`, if a partial order can/should be defined for
the value class in question.

Also the docstring of `Hashing` and its methods should give usage examples.

# How We Test This

Tests for the pony siphash-2-4 implementation should be written, at least ensuring it is equivalent to the C implementation in libponyrt.

If possible, it should be tested that the hash of a pony object using `Hashing` is a good hash function itself, possibly using some
test suite like SMHasher ( https://github.com/aappleby/smhasher ) or something similar.

# Drawbacks

* By introducing a pure pony implementation of SipHash-2-4, we have more pony code to test and maintain. Maybe it does not behave 100% like the C code
  would. Maybe differences will only appear on different platforms etc.
* We actually cannot remove the siphash implementation from libponyrt as the stringtab in libponyc still uses it.

# Alternatives

* A simple-stupid hash function (something like the bernstein hash function (http://www.cse.yorku.ca/~oz/hash.html)) could be used:

  ```pony
    fun hash(): USize =>
      var result = USiz(17)
      result = (result * 37) + _field1.hash()
      result = (result * 37) + _field2.hash()
      result
  ```

  It might be faster than siphash-2-4 but might lack some good properties expected from hash functions.

* Dot not reimplement SipHash in pure pony, but add the possibility of streaming uint64_t/uint32_t through it in libponyrt in C.
  After all, we can't really get rid of the siphash code in libponyrt, as we need the in the compiler for the `stringtab`s.

# Unresolved questions

* Naming:
  - What should be the name for classes whose identity is fully determined by its fields. In java-land, these are often called *value-classes*.
    In scala, inspired by category theory, these are called `case classes` or `Product types`.
  - Should the primitive containing convenience functions for hashing such objects be called `Hashing` or something else?


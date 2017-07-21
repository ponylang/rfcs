- Feature Name: more-random-methods
- Start Date: 2016-07-20
- RFC PR:
- Pony Issue:

# Summary

This RFC proposes the addition of various methods to the `Random` trait of the `random` package. It also proposes an additional method to the `Array` class.

# Motivation

The purpose of these additional methods is to increase the functionality of the `Random` trait.

# Detailed design

The following methods will be added to the `Random` trait, similar to the existing `u8`, `u16`, `u32`, `u64`, and `u128` methods:

```pony
  fun ref ulong(): ULong =>
    """
    A random integer in [0, ULong.max_value()]
    """

  fun ref usize(): USize =>
    """
    A random integer in [0, USize.max_value()]
    """
```

Additionally, the existing `int` method of the `Random` trait will be updated to allow specifying the integer type as a type parameter, instead of only supporting the `U64` type:

```pony
  fun ref int[N: (Unsigned val & Real[N] val) = U64](n: N): N =>
    """
    A random integer in [0, n)
    """
```

The following array-oriented method will also be added to the `Random` trait.

```pony
  fun ref shuffle[A](array: Array[A]) =>
    """
    Shuffle the elements of the array into a random order, mutating the array.
    """
```

To support `Random.shuffle`, the following method will be added to the `Array` class (because otherwise it is not possible to swap two elements in place without aliasing them):

```pony
  fun ref swap(i: USize, j: USize) ? =>
    """
    Swap the element at index i with the element at index j.
    If either i or j are out of bounds, an error is raised.
    """
```

# How We Teach This

The added methods will be properly documented as shown in this RFC.

# How We Test This

`Array.swap` and `Random.shuffle` will have unit tests to be sure that they work as expected.

# Drawbacks

The additional code will add a slight maintenance cost.

# Alternatives

Other methods may be added in addition or as replacements to the ones described above.

# Unresolved questions

None.

- Feature Name: string-array-trim
- Start Date: 2016-05-26
- RFC PR:
- Pony Issue:

# Summary

This change adds zero-copy `trim` and `trimmed` methods to the `Array` and `String` classes in the `builtin` package.

# Motivation

Currently, it is not possible to slice an `Array` or `String` without copying the underlying buffer into a newly allocated buffer.

Copying and allocation of large buffers are the bane of performance-critical sections, and finding ways to eliminate these operations when they are unnecessary can often improve performance dramatically.

This design would support the following use cases:

* mutating an existing mutable `Array` or `String` to discard all but the selected portion from it, using the `trim` method.

* sharing a selected portion of an immutable `Array` or `String`, using the `trimmed` method.

# Detailed design

I propose the following API changes to the `builtin` package.

* The following method will be **added** to `Array`, to support zero-copy, zero-allocation trimming of a mutable array to a portion of itself.

```pony
  fun ref trim(from: USize = 0, to: USize = -1): Array[A]^ =>
    """
    Trim the array to a portion of itself, covering `from` until `to`.
    Unlike slice, the operation does not allocate a new array nor copy elements.
    The same array is returned to allow call chaining.
    """
```

* The following method will be **added** to `Array`, to support zero-copy, zero-allocation sharing of a portion of an immutable array (well, okay, it *does* allocate a new `Array` object, but *not* a new underlying pointer and buffer).

```pony
  fun val trimmed(from: USize = 0, to: USize = -1): Array[this->A!] val^ =>
    """
    Return a shared portion of this array, covering `from` until `to`.
    Both the original and the new array are immutable, as they share memory.
    The operation does not allocate a new array pointer nor copy elements.
    """
```

* The following method will be **removed** from `Array`, as `trim` makes it obsolete.

```pony
  fun ref truncate(len: USize): Array[A]^ =>
    """
    Truncate an array to the given length, discarding excess elements. If the
    array is already smaller than len, do nothing.
    The array is returned to allow call chaining.
    """
```

* The following method will be **added** to `String`, to support zero-copy, zero-allocation trimming of a mutable array to a portion of itself.

```pony
  fun ref trim(from: USize = 0, to: USize = -1): String ref^ =>
    """
    Trim the string to a portion of itself, covering `from` until `to` bytes.
    The operation does not allocate a new string nor copy elements.
    The same string is returned to allow call chaining.
    """
```

* The following method will be **added** to `String`, to support zero-copy, zero-allocation sharing of a portion of an immutable string (well, okay, it *does* allocate a new `String` object, but *not* a new underlying pointer and buffer).

```pony
  fun val trimmed(from: USize = 0, to: USize = -1): String val^ =>
    """
    Return a shared portion of this string, covering `from` until `to` bytes.
    Both the original and the new string are immutable, as they share memory.
    The operation does not allocate a new string pointer nor copy elements.
    """
```

* The following method will be **added** to `String`, to support checking if the underlying string buffer is null-terminated. This wasn't necessary before, because even though strings are length-specified in Pony, `String` helpfully adds a null bytes but to all your strings implicitly for easier FFI compatibility with *some* C libraries that don't have length-specified functions and depend on null-terminators. However, this is necessary now, because `String`s created with the `trimmed` method share memory with another immutable `String`, and thus we can't set a null byte on the trimmed end of the buffer. This method will only really be useful to the minority of Pony programs/packages that need to call a null-terminator-dependent C function via FFI. Such a program should call this method, then use `clone` to produce a null-terminated copy of the string if necessary.

```pony
  fun is_null_terminated(): Bool =>
    """
    Return true if the string is null-terminated and safe to pass to an FFI
    function that doesn't accept a size argument, expecting a null-terminator.
    This method checks that there is a null byte just after the final position
    of populated bytes in the string, but does not check for other null bytes
    which may be present earlier in the content of the string.
    If you need a null-terminated copy of this string, use the clone method.
    """
```

# How We Teach This

* We should extend the Pony pattern about [limiting string allocations](https://github.com/ponylang/pony-patterns/blob/master/performance/limiting-string-allocations.md) to include a section about using `trim` and `trimmed`.

* We should lead by example, using `trim` and `trimmed` wherever applicable in the standard library and official Pony examples.

# Drawbacks

* For `String`, this introduces the possibility that the resulting `String` may not be null-terminated. As explained in the design section, this is only of interest to programs and packages that use FFI calls which do not allow a length to be specified, and this problem can be mitigated by checking `is_null_terminated` and using `clone` if necessary.

# Alternatives

Other designs considered:

* Use a wrapper object that is a `ByteSeq` and can apply as a virtual "slice" of any other `ByteSeq`, acting as an intermediary and erroring if the range is violated.

# Unresolved questions

None.

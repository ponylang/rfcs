- Feature Name: array-string-compact
- Start Date: 2016-06-10
- RFC PR: https://github.com/ponylang/rfcs/pull/12
- Pony Issue: https://github.com/ponylang/ponyc/issues/1012

# Summary

Add a `compact` function to `Array` and `String` in the `builtin` package. This function will get rid of unneeded allocated memory.

# Motivation

We can expand `Array`s and `String`s with `reserve` but we have no way to reduce the space without manually reallocating the object and copying the contents. This can result in lots of unused space if many objects are added and then removed in long-lived collections. The `compact` function addresses this concern.

# Detailed design

Add the following function to `builtin.Array`:

```pony
fun ref compact(): Array[A]^
  """
  Try to remove unused space, making it available for garbage collection. The
  request may be ignored. The array is returned to allow call chaining.
  """
```

Add the following function to `builtin.String`:

```pony
fun ref compact(): String ref^
  """
  Try to remove unused space, making it available for garbage collection. The
  request may be ignored. The string is returned to allow call chaining.
  """
```

The function will reallocate sufficient storage for the existing elements in the collection and will copy them to this new storage. The old storage can then be garbage collected.

As said in the docstrings the function may not do anything, specifically for small arrays. This is because small allocations (realised by `pony_alloc_small`, i.e. <= 512 bytes) are always rounded to a power of two. Because of this, we want to know when compacting is impossible to avoid unnecessary reallocations. Since `Array` is generic, `Array`s of different types could store objects of different sizes, which requires us to compute stored object sizes. This is possible with `Pointer._offset` but it is unclear and can lead to bugs caused by overflow in pointer arithmetic. Therefore, we'll add the following function to `builtin.Pointer`:

```pony
fun tag _element_size(): USize
  """
  The size of a single element in an array of type A.
  """
```

For performance reasons compacting should only be requested by the user and no function on `Array` and `String` should call `compact`.

# How We Teach This

This is a straightforward function and it is the mirror of the existing function `reserve`. As such, the function docstring should be sufficient.

# Drawbacks

None.

# Alternatives

Integrate the function with the runtime memory allocator and split allocated chunks when compacting is requested. This could lead to a lot of memory fragmentation.

# Unresolved questions

None.

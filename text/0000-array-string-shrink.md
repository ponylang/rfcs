- Feature Name: array-string-shrink
- Start Date: 2016-06-10
- RFC PR:
- Pony Issue:

# Summary

Add a `shrink_unused` function to `Array` and `String` in the `builtin` package. This function will get rid of unneeded allocated memory.

# Motivation

We can expand `Array`s and `String`s with `reserve` but we have no way to reduce the space without manually reallocating the object and copying the contents. This can result in lots of unused space if many objects are added and then removed in long-lived collections. The `shrink_unused` function addresses this concern.

# Detailed design

Add the following function to `builtin.Array`:

```pony
fun ref shrink_unused(): Array[A]^
  """
  Try to remove unused space, making it available for garbage collection. The
  request may be ignored. The array is returned to allow call chaining.
  """
```

Add the following function to `builtin.String`:

```pony
fun ref shrink_unused(): String ref^
  """
  Try to remove unused space, making it available for garbage collection. The
  request may be ignored. The string is returned to allow call chaining.
  """
```

The function will reallocate sufficient storage for the existing elements in the collection and will copy them to this new storage. The old storage can then be garbage collected.

As said in the docstrings the function may not do anything, specifically for small arrays. This is because small allocations (realised by `pony_alloc_small`, i.e. <= 512 bytes) are always rounded to a power of two. We can compute stored object sizes with `Pointer._offset` so we'll always know when shrinking is impossible.

For performance reasons shrinking should only be requested by the user and no function on `Array` and `String` should call `shrink_unused`.

# How We Teach This

This is a straightforward function and it is the mirror of the existing function `reserve`. As such, the function docstring should be sufficient.

# Drawbacks

None.

# Alternatives

Integrate the function with the runtime memory allocator and split allocated chunks when shrinking is requested. This could lead to a lot of memory fragmentation.

# Unresolved questions

None.

- Feature Name: C-string vs bytes
- Start Date: 2016-09-22
- RFC PR:
- Pony Issue:

# Summary

With the introduction of zero-copy trimming methods, some Pony strings are not null-terminated while some are. This is a proposal to ensure that `cstring()` always returns a pointer to null-terminated data, while at the same time having a new method `bytes()` return a pointer to the already allocated data (zero-copy) with no guarantee of null-termination.

# Motivation

The definition of a C-string is a null-terminated string. Hence, it's a reasonable guarantee for the `cstring()` method to give. Meanwhile, sometimes we're just interested in the raw string data (as a pointer) and for this use-case we'll introduce the `bytes()` method.

# Detailed design

The existing code to add null-termination to the allocated memory is kept since it's a small cost compared to the advantage that most of the time, `cstring()` will be zero-copy.

However, the current `null_terminated()` will be removed (it's now obsolete).

Adjustments to `from_cstring()` will be made such that it will no longer have a length argument. Instead, a new constructor `from_bytes()` is added.

Also, an array will no longer provide a `cstring()` method, but just `bytes()`.

# How We Teach This

The description of `cstring()` and in particular how it's used to interface with C needs to be updated.

# Drawbacks

None.

# Alternatives

The name `cpointer()` is suggested instead of `bytes()`.

# Unresolved questions

None.

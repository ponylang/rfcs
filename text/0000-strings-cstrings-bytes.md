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

There is a general lack of C FFI documentation for Pony and the implementation of this RFC should contribute here.

The docstring for `cstring()` today is "Returns a C compatible pointer to a null terminated string." which will actually be accurate if this RFC is implemented. But we should move the docstring contents from `null_terminated()` since it details the behavior when the underlying allocation is not already zero-terminated.

But the `String` class itself should also have a section that explains the existence of these two ways to extract a pointer to the raw data and how they're used.


# Drawbacks

Existing code might need updating, especially code that relies on the `cstring()` method of arrays where we most certainly will deprecate that method and use `bytes()` (or an alternative, see below.)

That said, code that relies on the old behavior of `String.cstring()` should still work the same since this RFC proposes to add a guarantee that the returned string is zero-terminated.


# Alternatives

The name `cpointer()` is suggested instead of `bytes()`.

# Unresolved questions

None.

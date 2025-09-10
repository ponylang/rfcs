- Feature Name: Modify String.copy\_cpointer() and String.copy\_cstring() to return iso^
- Start Date: 2025-09-10
- RFC PR:
- Pony Issue:

# Summary

The two current constructors `String.copy_cpointer()` and `String.copy_cstring()` both take a `Pointer[U8] box` and return a `String ref^`. Given that these two constructors make copies, returning a `String iso^` would be preferable and safe.

Note: In the interests of clarity of writing, I will use `String.copy_cstring()` throughout the rest of this RFC. All of the commentary below should be read to apply to both `String.copy_cstring()`, and `String.copy_cpointer()`.

# Motivation

In many cases, as a library author I want to provide my end-users a mutable and sendable copy of a String received via C-FFI. In other words, a `String iso^`. With the way that the String library is currently written, there are two ways to do this:

## Create a String ref^ using String.from\_cstring() or from\_cpointer() and clone().

```pony
  var str: String iso = String.from_cstring(ptr).clone()
```

The main issue with this is that it directly violates the documentation which states: "This must be done only with C-FFI functions that return pony\_alloc'd character arrays".

## Create a String ref^ using String.copy\_cstring() and clone()

```pony
  var str: String iso = String.copy_cstring(ptr).clone()
```

This does not violate the documentation and does a clean copy into a new `String ref^`. Unfortunately, the clone() that follows to generate the `String iso^` we need results in a second copying of the data.

Since the `String.copy_cstring()` does a clean copy, it would be a safe operation to return a `String iso^`, making the second copying redundant.

Ideally, the change would result in the following use:

```pony
  var str: String iso = String.copy_cstring(ptr)
```

# Detailed design

The existing `String.copy_cstring()` and `String.copy_cpointer()` have the following signatures:

```pony
new ref copy_cstring(str: Pointer[U8 val] box)
new ref copy_cpointer(str: Pointer[U8 val] box, len: USize val)
```

The reason that we cannot just change the return type to `String iso^` is that `str: Pointer[U8] box` is not sendable. The ideal outcome would be to not change the `Pointer[U8] box` to `Pointer[U8] val` in order to not create a breaking change.  Here are two proposed ways to achieve this:

## Convert from constructors to functions

The main disadvantage to this approach is that it does cause an additional creation of an (empty) `String` in addition to the `String iso^` it would return. That feels "impure"™. An implementation might look something like this:

```pony
  fun copy_cpointer(ptr: Pointer[U8] box, len: USize): String iso^ =>
    """
    Create a string by copying a fixed number of bytes from a pointer.
    """
    let str: String iso = recover iso String(len + 1) end
    if not ptr.is_null() then
      ptr._copy_to(str._ptr._unsafe(), len)
      str._set(len, 0)
      str.recalc()
    end
    consume str
```

## Retain the constructor, but change the receiver to Pointer[U8] tag

```pony
new iso copy_cstring(str: Pointer[U8 val] tag)
```

As there is a copying mechanism this doesn't break safety, but it does break the expectation that you cannot get data out of a `Pointer[U8] tag`.

# How We Teach This

The aim of this RFC is for there to be no user impact, so no new information will need to be shared.

# How We Test This

There are currently no tests for `String.copy_cstring()` or `String.copy_cpointer()` in builtin_tests. My initial PR included some.

# Drawbacks

The first proposal doesn't feel "correct", creating an object via a function, and not using the calling object.

The second proposal although not breaking safety, does break expectations that have been set over time.

# Alternatives

## Change the signature to only accept `Pointer[U8] val`

This would be a trivial but breaking change. A review of stdlib and the libraries in the github ponylang repositories finds no clear cases where I think this would break.

```pony
new iso copy_cstring(str: Pointer[U8 val] val)
```

## Leave copy_cstring() as is, add copy_cstring_iso()

This would be a trivial non-breaking change, and there is existing precedent for including refcaps in function names: `String.from_iso_array()`.

```pony
new iso copy_cstring_iso(str: Pointer[U8 val] val)
```

# Unresolved questions

Although the ideal of not making a breaking change is strong, it may result in being the most correct way forward.

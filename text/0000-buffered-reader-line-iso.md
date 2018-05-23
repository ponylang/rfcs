- Feature Name: buffered-reader-line-iso
- Start Date: 2018-05-23
- RFC PR:
- Pony Issue:

# Summary

Change the return type of the function `buffered.Reader.line` from:

```pony
fun ref line(): String ? =>
```

to return `String iso^` instead:

```pony
fun ref line(): String iso^ ?
```

# Motivation

The initial motivation was the [PR 2707](https://github.com/ponylang/ponyc/pull/2707) which reimplemented `files.FileLines`
to iterate over `String iso^` instead of `String val`. `buffered.Reader` was used to implement this and its implementation
of `line` is allocating a new String and returns it as `val`. This is in contrast to nearly all other methods that extract bytes from an external resource. A `TCPConnectionNotify` gets an `Array[U8] iso`, `File.read` returns an `Array[U8] iso^`, `File.line` (although being removed) returns a `String iso^` etc. This also requires the users of `buffered.Reader.line` to copy the String in order to mutate it.

Returning an ephemeral `String iso^` is more powerful as such a String is both mutable and sendable. It is also, to some degree, backwards compatible as it can be automatically recovered to a `String val`: 

```pony

class Example
  fun iso_string(): String iso^ =>
    recover String.>append("foo") end
    
actor Main
  new create(env: Env) =>
    let s: String val = Example.iso_string()
```

# Detailed design

The return type of `buffered.Reader.line` will be changed to `String iso^` and the code using this method will be updated in case it is relying on type inference to infer the refcap of the String to be `val`. This should boil down to add a few recover or consume calls here and there in the stdlib and the examples.

# How We Teach This

There is not much to teach besides a proper changelog entry and some detailed release notes.

# How We Test This

In general, no tests need to be added to this. The existing tests need to be adapted in case they do not compile anymore with this change.

# Drawbacks

* Breaks existing code

# Alternatives

Implement a `buffered.Reader.iso_line` method that returns a `String iso^`. But this entails a lot of unnecessary code duplication.

# Unresolved questions

None.

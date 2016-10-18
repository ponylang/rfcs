- Feature Name: String split zero-copy
- Start Date: 2016-10-18
- RFC PR:
- Pony Issue:

# Summary

The string splitting method should work on an immutable copy and provide a "zero-copy" functionality.

# Motivation

This behavior is preferable because you get to decide whether to make zero or one copy of the complete string. It's easy to obtain an immutable copy of a string so usability is preserved.

# Detailed design

The splitting method will be revised to operate on the immutable string only, returning immutable zero-copy reference strings to the same memory allocation.

The previous method signature was:
```pony
fun split(delim: String = " \t\v\f\r\n", n: USize = 0): Array[String] iso^ =>
```
This would be changed to:
```pony
fun val split(delim: String = " \t\v\f\r\n", n: USize = 0): Array[String] val^ =>
```

Typical usage:
```pony
let words = "Hello world".split()
let s = "1,2,3".clone()
let numbers = s.split(",")
```
The latter example relies on auto-recover to make the cloned ``String iso`` immutable.

# How We Teach This

This API is a good candidate for inclusion in the tutorial. It's a common operation and it highlights how reference capabilities fit naturally in library design.

# How We Test This

The existing tests will be adapted.

#### Drawbacks ####

This breaks existing code.

# Alternatives

Not considered.

# Unresolved questions

No open questions.

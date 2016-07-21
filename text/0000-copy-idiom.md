- Feature Name: copy-idiom
- Start Date: 2016-07-21
- RFC PR:
- Pony Issue:

# Summary

Extend the current idiom for object copying in the standard library with a `from` constructor in addition to the `clone` function.

# Motivation

The current "standard" way of copying an object is with the `clone` function (usual signature: `fun clone(): Object iso^`). While this function is very useful in some situations, like copying an `iso` object without consuming said object, it has limitations. For example it isn't possible to construct an embedded field with a copy of another object. Adding copying constructors would solve that problem.

# Detailed design

The copying functions should be provided as:

```
class Object
  new from(that: Object box)

  fun clone(): Object iso^
```

This interface should only be a basic template and per-class modifications should be allowed, such as changing the return capability of `clone`. It should also be allowed to not provide `clone` if every operation can be done with `from` (for example in numeric primitives).

# How We Teach This

Advocating for the use of this idiom in user libraries would be good for the consistency of the Pony ecosystem. We could talk about object copying in the tutorial and recommend the `from` and `clone` names in copyable classes.

# Drawbacks

This can introduce some code duplication between `from` and `clone`.

# Alternatives

None.

# Unresolved questions

None.

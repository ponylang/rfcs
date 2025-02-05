- Feature Name: string_find_usize
- Start Date: 2024-12-09
- RFC PR: https://github.com/ponylang/rfcs/pull/216
- Pony Issue: https://github.com/ponylang/ponyc/issues/4587

# Summary

Change the return type of `String.find`  and `String.rfind` from `ISize` to `USize`, aligning its return type with `Array.find`.

# Motivation

The current return type of `String.find` and `String.rfind` is `ISize`, which stems from its historical behavior of returning `-1` when no match was found. However, these methods now return `error` for such cases. Returning `USize` makes more sense because indices are always non-negative, and it aligns with `Array.find`'s method signature.

# Detailed design

The method signature of [String.find](https://github.com/ponylang/ponyc/blob/736220a34364a864fe0fd1f091a85852ded84d23/packages/builtin/string.pony#L640) and [String.rfind](https://github.com/ponylang/ponyc/blob/736220a34364a864fe0fd1f091a85852ded84d23/packages/builtin/string.pony#L669) would change to return `USize` instead of `ISize`.

Specifically, the method signatures would be changed from this:

```pony
fun find(s: String box, offset: ISize = 0, nth: USize = 0): ISize ?
fun rfind(s: String box, offset: ISize = -1, nth: USize = 0): ISize ?
```

to this:

```pony
fun find(s: String box, offset: ISize = 0, nth: USize = 0): USize ?
fun rfind(s: String box, offset: ISize = -1, nth: USize = 0): USize ?
```

# How We Teach This

Through the standard library documentation and the associated release notes.

# How We Test This

Standard CI and the compiler should identify any additional code areas that are needed. Sean T. Allen did a review of the tutorial, pony patterns, and the website and found no changes that would be needed to reflect the new behavior.

# Drawbacks

It's a breaking change as the method signature has to change. Existing code relying on `String.find` and `String.rfind` will need to be migrated.

# Alternatives

Keep the existing method signature to avoid breaking changes introduced by this proposal.

# Unresolved questions

None at this time.

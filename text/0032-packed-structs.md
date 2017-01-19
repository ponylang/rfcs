- Feature Name: packed-structs
- Start Date: 2016-12-25
- RFC PR: https://github.com/ponylang/rfcs/pull/72
- Pony Issue: https://github.com/ponylang/ponyc/issues/1523

# Summary

Add program annotations allowing programmers to declare packed structures, i.e. structures without implementation-specific padding between members.

# Motivation

In C, packed structures are a common idiom when doing I/O. Pony is currently unable to interface with this kind of structures, adding this capability would be good for the FFI and the language.

# Detailed design

The proposed annotation is `packed`, and would affect `struct` declarations:

```pony
struct \packed\ MyPackedStruct
  // Members.
```

The code generation for these structures will use LLVM's packed structures, which are very simple to use.

# How We Teach This

Plain structures aren't currently explained in the tutorial. We should add an explanation in the "Calling C from Pony" and describe packed structures in the same place. In particular we will stress that, as normal Pony structures should only be used with normal C structures, packed Pony structures should only be used with packed C structures.

# How We Test This

The implementation will directly map onto LLVM's facilities and packed types. We'll add some tests checking that the LLVM type generated for a packed structure is indeed packed, to make sure nobody accidentaly breaks the implementation in the frontend.

# Alternatives

Not implementing this will leave the packed structures deficiency in the FFI unresolved.

# Unresolved questions

None.

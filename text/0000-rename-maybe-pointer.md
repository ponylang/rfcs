- Feature Name: rename_maybe_pointer
- Start Date: 2019-07-30
- RFC PR:
- Pony Issue:

# Summary

This RFC proposes renaming the `MaybePointer` struct of the `builtin` package to `StructPointer`.

# Motivation

The current name, `MaybePointer`, has caused confusion for many Pony users who are either new to the language or using the C Foreign Function Interface (C-FFI) for the first time. As I understand it, the purpose of `MaybePointer` is for passing pointers to structs across the C-FFI boundary where those pointers may be null. `StructPointer` may lead to less confusion for users searching through the standard library for the functionality that this struct provides.

# Detailed design

The `MaybePointer` struct in builtin will be renamed to `StructPointer`. It will otherwise remain unchanged.

# How We Teach This

The "Calling C from Pony" section of the tutorial will require an update for the name change.

# Drawbacks

This change will break much of the existing Pony code that uses C-FFI and Pony structs.

# Alternatives

An alternative name may be `NullableStructPointer`. However, this name is a bit verbose.

# Unresolved questions

None

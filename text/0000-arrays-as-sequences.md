- Feature Name: Arrays As Sequences
- Start Date: 2017-03-11
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Use a sequence to define an array literal instead of a comma separated list of sequences.

# Motivation

Previously, a comma `,` was used to separate array elements. In Pony, a comma is the tuple operator, and as a result, an array appeared to be composed of a tuple of elements.

This change defines an array as a sequence of elements instead. As a result, no separator is needed when elements are on new lines, or a semicolon `;` (i.e. the sequence operator) can be used when elements are on the same line.

This change means that all instances of `,` in Pony indicate a tuple (including, logically speaking, parameter lists, arguments, type arguments, etc.) and all instances of `;` indicate a sequence.

# Detailed design

The parser is changed to take a single sequence instead of a comma separated list of sequences. The `TK_ARRAY` AST node now has two children, so can iterate directly on elements in `expr_array`. In `coerce_group`, if the group is a `TK_ARRAY`, we use its element sequence, rather than skipping one AST child and treating the remainder as elements.

The only subtle part is that in `expr_seq`, we must check if the `TK_SEQ` is a child of a `TK_ARRAY`. If it is, we skip processing on the sequence, and allow it to be handled in `expr_array`. This is to allow literal type inference to work on all elements of an array sequence.

# How We Teach This

Initially by changing example to use `;` instead of `,` as a separator, and by having examples where elements are on separate lines, and so need no separator at all.

More conceptually, by emphasising that an array is a sequence, and that a sequence is fundamentally different from a tuple.

# How We Test This

By changing existing array tests, plus by updating the standard library to use `;`.

# Drawbacks

* This breaks existing code.

# Alternatives

Leave `,` as being ambiguous as to whether it indicates a tuple or a sequence.

# Unresolved questions

None.

- Feature Name: remove-delegate
- Start Date: 2016-12-26
- RFC PR: https://github.com/ponylang/rfcs/pull/73
- Pony Issue: https://github.com/ponylang/ponyc/issues/1514

# Summary

This RFC proposes the removal of delegates from the language features.

# Motivation

Delegates are rarely used in real-world code (for example, this feature isn't used at all in the current standard library) and are often confusing for new users.

# Detailed design

We would remove the implementation and tests for delegates from the compiler and the explanation and examples from the tutorial.

# How We Teach This

An email on the mailing list could be sent to inform everybody of the feature removal.

# Drawbacks

This is a breaking change (although it probably won't have a huge impact on existing code).

# Unresolved questions

None.

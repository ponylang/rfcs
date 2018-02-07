- Feature Name: remove-case-functions
- Start Date: 2018-01-13
- RFC PR: https://github.com/ponylang/rfcs/pull/118
- Pony Issue: https://github.com/ponylang/ponyc/issues/2540

# Summary

Remove the existing case functions implementation from Pony.

# Motivation

Case functions are an awesome idea. The current implementation is problematic. Its synatic sugar over match statements and fraught with edge cases where the edge case is often the common case.

The current implementation is mostly unusable. Additionally, it has from time to time been the source of bugs elsewhere in the Pony codebase (usually related to match).

# Detailed design

Step 1:

Remove "case function" section from the tutorial.

Step 2:

Remove from compiler

Step 3:

Someone drafts an RFC to reimplement case functions in a sane fashion.

# How We Teach This

As part of the release notes for the release that includes this breaking change, we should give an example of how to turn your case functions into a single function that uses a match to execute.

# How We Test This

Current CI tests should continue to pass.

# Drawbacks

- This is a breaking change and might force folks to rewrite some of their code.
- Corresponding match statements might be pretty ugly


# Alternatives

We could leave case functions in the language while reworking the implementation.

# Unresolved questions

I'm not intimately familiar with where in the codebase case functions are implemented so "detailed design" section of this RFC is lacking in details.

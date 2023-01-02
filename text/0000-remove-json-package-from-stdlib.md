- Feature Name: Remove json package from the standard library
- Start Date: 2023-01-02
- RFC PR:
- Pony Issue:

# Summary

Remove the `json` package from the standard library and move it to a its own repository under the ponylang organization on GitHub.

# Motivation

The json package is a regular source of difficult for Pony users. It is an ok API for some JSON handling needs and a poor API for other needs. The package
parses a String representation of some JSON into a mutable tree of objects.

This mutable tree is excellent for modifying the JSON, it is also an excellent representation for constructing a JSON document. However, it makes parsing a String into an shareable data structure that can be sent between actors very difficult.

It is my view that the Pony ecosystem would be better served by not having an "official" JSON library that is part of the standard library. We would be better of my encouraging many different libraries that approach the problem differently. Sometimes, a purely functional approach like that taken by [jay](https://github.com/niclash/jay/) is called for. Other times, an approach that tightly controls memory usage and other performance oriented characteristics is better as seen in [pony-jason](https://github.com/jemc/pony-jason).

Having the current `json` package in the standard library given all its failings is a bad look. Better to have someone ask "what's the best way to handle JSON" then to blindly start using the existing package.

The existing package could be improved and it is best improved outside of the standard library and RFC process. The RFC process intentionally moves slowly. The `json` package is at best "beta" level software and would be greatly enhanced by a process that allows for more rapid change and experimentation. Further, it isn't essential to the community that a JSON library be part of the standard library. There's no cross library communication mechanism that depends on the existence of a standard JSON handling interface.

Given all these considerations, I am writing this RFC to move the `json` package from the standard library to a repository of its own.

# Detailed design

Remove the `json` package from the standard library. Set it up in the "standard ponylang organization library format" at github.com/ponylang/json.

In the README documentation for the library, we should spend time noting the use cases that the library is currently good for and those that it is not. In particular, highlight that it appropriate for building documents and mutating them, but is problematic for creating shareable object representations.

# How We Teach This

In the release notes for the ponyc where the removal is done, we should explain the basics of why the removal was done and how to update code that relies on the package to pull in from corral and be used.

# How We Test This

Existing unit tests will be run in the new repository.

# Drawbacks

This will break existing code.

# Alternatives

Leave the library as is and someone could work on an RFC to change the library in place. The drawback to that approach is that each change to update to usage patterns would need a further RFC making any iterative design process difficult.

# Unresolved questions

None.

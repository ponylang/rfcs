- Feature Name: Unix Domain Socket Support
- Start Date: 2021-11-22
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

The intent is to extend to runtime library, together with the `net` package, to
add support for Unix domain sockets. That is, currently there is support for TCP
and UDP sockets, but not for Unix domain sockets.

# Motivation

Unix domain sockets, and in particular, named Unix domain sockets can provide
interprocess communications support that is well suited to modular component
development under Unix. Additionally, integration with existing services
sometimes requires interaction via named unix domain sockets.

# Detailed design

TODO

This is the bulk of the RFC. Explain the design in enough detail for somebody familiar with the language to understand, and for somebody familiar with the compiler to implement. This should get into specifics and corner-cases, and include examples of how the feature is used.

# How We Teach This

TODO

What names and terminology work best for these concepts and why? How is this idea best presented? As a continuation of existing Pony patterns, or as a wholly new one?

Would the acceptance of this proposal mean the Pony guides must be re-organized or altered? Does it change how Pony is taught to new users at any level?

How should this feature be introduced and taught to existing Pony users?

# How We Test This

TODO

How do we assure that the initial implementation works? How do we assure going forward that the new functionality works after people make changes? Do we need unit tests? Something more sophisticated? What's the scope of testing? Does this change impact the testing of other parts of Pony? Is our standard CI coverage sufficient to test this change? Is manual intervention required?

In general this section should be able to serve as acceptance criteria for any implementation of the RFC.

# Drawbacks

TODO

Why should we *not* do this? Things you might want to note:

* Breaks existing code
* Introduces instability into the compiler and or runtime which will result in bugs we are going to spend time tracking down
* Maintenance cost of added code

# Alternatives

TODO

What other designs have been considered? What is the impact of not doing this?
None is not an acceptable answer. There is always to option of not implementing the RFC.

# Unresolved questions

TODO

What parts of the design are still TBD?

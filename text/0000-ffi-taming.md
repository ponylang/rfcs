- Feature Name: ffi-taming
- Start Date: 2016-08-30
- RFC PR:
- Pony Issue:

# Summary

Apply a uniform taming policy to FFI in the pony standard library
and document it as a best practice for the community. In brief,
the policy is to "dominate" all impure FFI calls with AmbientAuth.

# Motivation

The result of such a policy is to remove ad-hoc trust from the FFI boundary,
resulting in the same safety and robust composition as the rest of pony.

The tutorial currently says:

> What about global variables?
>
> They're bad! Because you can get them without either constructing them or being passed them.
>
> Global variables are a form of what is called ambient authority. Another form of ambient authority is unfettered access to the file system.
>
> Pony has no global variables and no global functions. That doesn't mean all ambient authority is magically gone - we still need to be careful about the file system, for example. Having no globals is necessary, but not sufficient, to eliminate ambient authority.

But actually, we don't need to be careful about the filesystem, at least as
exposed by the pony files package. It does not provide unfettered access to the filesystem;
all access is "fettered" directly by AmbientAuth capabilities or indirectly
by FilePath capabilities.

While we can't magically get rid of all ambient authority, we can feasibly
get rid of it from the standard library with careful application of object
capability discipline and we can establish this as a best practice for the community.

# Detailed design

This is the bulk of the RFC. Explain the design in enough detail for somebody familiar with the language to understand, and for somebody familiar with the compiler to implement. This should get into specifics and corner-cases, and include examples of how the feature is used.

# How We Teach This

What names and terminology work best for these concepts and why? How is this idea best presented? As a continuation of existing Pony patterns, or as a wholly new one?

Would the acceptance of this proposal mean the Pony guides must be re-organized or altered? Does it change how Pony is taught to new users at any level?

How should this feature be introduced and taught to existing Pony users?

# Drawbacks

Why should we *not* do this?

# Alternatives

What other designs have been considered? What is the impact of not doing this?

# Unresolved questions

What parts of the design are still TBD?

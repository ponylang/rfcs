- Feature Name: ffi-taming
- Start Date: 2016-08-30
- RFC PR:
- Pony Issue:

# Summary

Apply a uniform taming policy to FFI in the pony standard library
and document it as a best practice for the community. In brief,
the policy is to "dominate" all impure FFI calls with `AmbientAuth`.

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
exposed by the pony `files` package. It does not provide unfettered access to the filesystem;
all access is "fettered" directly by `AmbientAuth` capabilities or indirectly
by `FilePath` capabilities.

While we can't magically get rid of all ambient authority, we can feasibly
get rid of it from the standard library with careful application of object
capability discipline and we can establish this as a best practice for the community.

# Detailed design

Some FFI calls are pure mathematical functions: given the same inputs, they
return the same outputs, and they have no other observable affect on the system.

For any other FFI call, such as one that accesses the filesystem or network
or clock or process lists or thread-local storage, pony function that makes
the FFI call must take an `AmbientAuth` argument, either directly or indirectly, as
in the case of `FilePath`, `NetAuth` and the like.

Much of the pony standard library is already organized this way, but there
are exceptions such as `Time.now()`.

Correctness is still very much an issue - a C function can "stomp memory addresses,
write to anything, and generally be pretty badly behaved."
But this is already adequately documented.

# How We Teach This

The "What about global variables?" section of the tutorial should be revised
to reflect this policy as well as the trust boundary section and documentation
of the `--safe` flag.

Just as the tutorial cites "Capability Myths Demolished" there is a certain
amount of literature to draw from:

 - [Joe-E: A Security-Oriented Subset of Java](https://people.eecs.berkeley.edu/~daw/papers/joe-e-ndss10.pdf) Adrian Mettler, David Wagner, and Tyler Close. ISOC NDSS 2010.
 - [A Security Analysis of the Combex DarpaBrowser Architecure](http://www.combex.com/papers/darpa-review/security-review.html) by David Wagner & Dean Tribble March 4, 2002
   - especially section 5.2    Taming the Java Interface.
 - [A Theory of Taming](http://erights.org/elib/legacy/taming.html)

# Drawbacks

  - API churn
  - time cost to audit the standard library
  - additional code review burden going forward
  - possible false sense of security if we don't get it right

# Alternatives

  - Leave the existing ad-hoc trust boundardy in place
    - Drawback: each adopter of pony has to scan the source of the pony standard library (as well as every other library they adopt) to see if it's consistent with the policies of their application.

# Unresolved questions

 - Make an exception for logging/tracing?
   - This is somewhat traditional; e.g. section 6.2 of the DarpaBrowser paper says "The renderer can call a tracing service to output debugging messages."
 - A review of all FFI calls in the standard library is in order to refine the detailed design.


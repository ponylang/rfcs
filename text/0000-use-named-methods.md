- Feature Name: Use named methods instead of apply/update
- Start Date: 2016-05-30
- RFC PR:
- Pony Issue:

# Summary

This is a proposal to use named methods throughout the standard library as opposed to using the "apply" and "update" methods that are generally chosen because they map to the callable and assignment sugar.

Some objects have just a single "apply" method which supports an inline implementation as a lambda function (an object literal). This will still be possible, but it should no longer be a requirement that the single method be named "apply".

# Motivation

The primary motivation is to provide a uniform object interface and
secondly that named methods communicate more clearly at both the point
of definition and at call sites.

The syntax sugar that some languages have for member assignment and
the like may result in less precise object interfaces that map poorly
to the underlying algorithms. The use of named methods throughout the
codebase helps steer clear of this pitfall.

In addition, the terms "apply" and "update" are often not particularly meaningful. For example, a method to obtain an HTTP status code would be better named "code" (instead of "apply"), and the method to send a request from an HTTP client might be "request" (instead of "apply".)

# Detailed design

There are some 200 implementations in the standard library of an
"apply" method and about a dozen "update" methods which would all need to be renamed. The process of coming up with suitable names is out of scope for the RFC process and should be discussed during implementation.

# How We Teach This

This proposal represents a more simple library design and so there will be less to teach.

# Drawbacks

The "apply" and "update" sugar makes the code more compact.

# Alternatives

No alternative is currently proposed.

# Unresolved questions

It's currently unresolved whether the "update" sugar should still be supported (it's clear that "apply" has obvious uses such as having an object pass for a function).

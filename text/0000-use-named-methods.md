- Feature Name: Use named methods when possible
- Start Date: 2016-05-30
- RFC PR:
- Pony Issue:

# Summary

This is a proposal to use named methods when possible, leaving the use
of the "apply" syntax sugar to function-like objects and dropping the
"update" sugar altogether. This directly affects a number of classes
in the standard library which currently use "apply" and "update" for
methods such as getting or setting an item.


# Motivation

The primary motivation is to provide a uniform object interface and
secondly that named methods communicate more clearly at both the point
of definition and at call sites.

The syntax sugar that some languages have for member assignment and
the like may result in less precise object interfaces that map poorly
to the underlying algorithms. The use of named methods throughout the
codebase helps steer clear of this pitfall.

In addition, the term "apply" in particular is typically not very
meaningful in the context of an action such as getting an item from a
collection. We can note that most objects are likely to have a default
or primary action that is not well described with the term "apply".


# Detailed design

There are some 200 implementations in the standard library of an
"apply" method and about a dozen "update" methods.

If this RFC is admitted into the repository there needs to be a
process of deciding new names. For example, unit tests currently have
an "apply" method which could be renamed to "run", while the logger
object could have its "apply" method renamed to "append".


# How We Teach This

The documentation needs to be updated.


# Drawbacks

The "apply" and "update" sugar make some operations more compact.


# Alternatives

The bracket notation is a common syntax choice for item assignment and
retrieval. It would be an option to introduce additional sugar to map
special methods to this notation.


# Unresolved questions

A complete list of suggested renames has not been developed at this
time.

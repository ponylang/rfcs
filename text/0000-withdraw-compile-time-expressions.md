- Feature Name: withdraw-compile-time-expressions
- Start Date: 2026-04-29
- RFC PR:
- Pony Issue:

# Summary

Withdraw RFC 53, "Compile-Time Expressions". The original RFC stays in the repository as a historical record but is no longer an accepted proposal.

# Motivation

RFC 53 was accepted in 2018 and has never been implemented. Reading it now, the RFC is underspecified. The text leaves several core questions about the feature open:

- Whether a compile-time expression takes the capability of the underlying expression or is always `val` is presented as two alternatives, with no decision.
- Whether `error` inside a compile-time expression resolves at compile time or halts compilation is presented as two alternatives, with no decision.
- Floating point semantics across host and target are flagged as a problem without an answer.
- The subset of the language permitted at compile time is described as "a large subset", left as a future task.

These are not edge cases. They define what the feature does. An accepted RFC that does not answer them is not a specification.

The idea is interesting and worth pursuing. We would happily accept a fuller proposal that pins these questions down. The expectation for any future RFC on this topic is that it is accompanied by a working implementation that can be evaluated alongside the design.

# Detailed design

Add a note to the top of `text/0053-compile-time-expression.md` recording that the RFC has been withdrawn and pointing to this RFC.

Close ponyc issue #2591 with a comment pointing at this RFC.

# How We Teach This

Nothing to teach. RFC 53 was never implemented and no user code depends on it.

# How We Test This

Nothing to test. No code changes are involved.

# Drawbacks

None. RFC 53 was never implemented and no work is in progress against it.

# Alternatives

Leave RFC 53 on the accepted list. This keeps an "accepted" RFC that does not actually specify the feature it proposes.

Edit RFC 53 in place to fill the gaps. The process treats accepted RFCs as substantively immutable; the gaps here are substantive, not minor edits.

# Unresolved questions

None.

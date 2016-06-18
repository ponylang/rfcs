- Feature Name: Try, else, no "then"
- Start Date: 2016-06-10
- RFC PR:
- Pony Issue: #291

# Summary

Drop "then" clause from "try/else" clause.


# Motivation

The behavior is orthogonal to error handling. It applies in general
when leaving a code block.

The "with" statement already provides the necessary functionality for
obtaining and giving up a resource such as a lock or file handle. In
addition the "with" statement supports multiple such resources at the
same time without additional nesting.


# How We Teach This

In the documentation we need to talk about what resource management is
and how the "with" statement conceivably solves the problem. Since in
some languages exception handling is used for flow control it might
also be good to talk about this.


# Drawbacks

The main drawback is that code that uses "try/else/then" today will
need to be updated to use a "with" block which needs object support in
the form of a "dispose method".


# Unresolved questions

Currently none.

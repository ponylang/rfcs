- Feature Name: behaviour-return-none
- Start Date: 2016-11-16
- RFC PR:
- Pony Issue:

# Summary

Change the return value of behaviour calls from the receiver to `None`.

# Motivation

With the recent implementation of caller-side method chaining, there is no reason for behaviour calls to return their receiver. Changing the return value to `None` will also be more consistent with the `fun` syntax (i.e. `fun foo()` and `be foo()` would respectively be (conceptually) equivalent to `fun foo(): None` and `be foo(): None`).

# Detailed design

Simply make behaviour calls return `None`. This will affect behaviour/function subtyping, for example `be foo()` will now be a subtype of `fun tag foo()` instead of `fun tag foo(): ReceiverType`.

# How We Teach This

The tutorial section on behaviour call return values will have to be updated.

# Drawbacks

This is a breaking change.

# Unresolved questions

None.

- Feature Name: partial_arithmetic
- Start Date: 2018-05-23
- RFC PR:
- Pony Issue:

# Summary

This RFC suggests adding partial versions of basic Integer arithmetic operators (`+`, `-`, `*`, `/`, ...)
that error on overflow or underflow or division by zero. These new operator should combine the base-operators with a `?`:
`+?`, `-?`, `*?`, `/?`, ...

# Motivation

The initial motivation was to give people an easy way to get signalled when we run into unwanted condition during arithmetic operations on Integers. It is currently quite cumbersome to guard against division by zero as one has to check the divisor to not be `0` every time. Having a concise way of erroring on this condition would make it possible to write safe code, that is aware of bad things that can happen, without sacrificing correctness of the computation.

There has been some discussions around Pony, mentioning that it is weird that division by zero is silently swallowed and transformed to `0`, while the rest of the language is focusing on safety. This has been considered kind of an inconsistency by quite a few people (from personal conversations). I know division has been deliberately changed to be non-partial, mostly for pragmatic reasons. This RFC wants to give the user a way to gain the safety back with a built-in operator, that is partial and errors on division by zero. This might not be too practical in day-to-day usage but it gives users the built-in tools to write safe arithmetic, if they desire to do so.

For not having division stand out amongst the arithmetic operations, and for giving users an interface that is expectable ans consistent across operations, all other basic arithmetic operations should get a partial counterpart, that errors on underflow, overflow, comparable to the existing `addc`, `subc` and `mulc` functions.


# Detailed design

The operators need to be added in the parser.

They should be made customizable, so that users can write a partial `add` function for their objects, and make use of `+?` for adding two of their objects in a partial way. The method names should be the names for the base operations with a `_partial` suffix. E.g. `sub_partial` for partial subtraction.

The actual implementation is quite simple, for addition, subtraction and multiplication we can use `addc`, `subc` and `mulc` and match on `overflow` flag and error if it is `true`. For division, we can simply check the divisor for being `0` and error in that case.

# How We Teach This

The new methods added need to have docstrings explaining their behavior. The docstrings of the other methods should mention the other method of doing e.g. addition.

The tutorial should introduce the different ways of doing arithmetic in greater detail, *checked* (`addc` etc.), *unchecked* (`add` etc.). *unsafe* ( `add_unsafe` etc.) and *partial* (`add_partial`). So that users know what options they have and what the drawbacks might be (e.g. performance against correctness).

# How We Test This

There needs to be at least one additional Pony unit test that tests the error conditions of the new operators.

There need to be new compiler tests that ensure that the method-operator resolution works correctly, similar to how the existing operators are resolved.

# Drawbacks

This adds more code to the parser and adds more symbols and special methods to pony objects.
Also having 4 different kinds of doing basic arithmetic operations is a lot to grasp and to teach.


# Alternatives

One Alternative would be to extract these operations into a primitive that contains generic methods that work on any integer type, implementing the partial methods. The downside to this is that we don't get to have these partial arithmetic function usable for all kinds of classes.

Another one would be to only implement partial division and leave all other operators as they are.


# Unresolved questions

None.

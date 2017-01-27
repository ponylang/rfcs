- Feature Name: stateful-exceptions
- Start Date: 2017-01-27
- RFC PR:
- Pony Issue:

# Summary

Allow exceptions to carry a value from the error site to the handling site, while keeping the exception handling static. The value or its type aren't involved in destination checking. Exceptions will still land at the first handler encountered, with negligible additional runtime cost.

# Motivation

We currently have two very distinct idioms to handle errors in the language and standard library.

1. Exceptions. They are used most of the time but since they are valueless, they can't be used to propagate the reason of an error to a caller function.
2. Union types of the normal result and the error reason(s). This is used when the reason of an error is needed by a caller function (e.g. the constructors of `File` in the standard library).

Number 2 has several drawbacks. In particular

- The type of the result must be asserted via pattern matching, which introduces a runtime cost even in the non-erroring cases
- The error condition must be propagated manually through every calling function, unlike a "fire and forget" exception

In addition, having two different ways of doing almost the same thing isn't good for the overall consistency of the language and libraries.

Having this feature would also make the exception system a lot more versatile. By default it will still permit fast and static exception handling, while allowing programmers to manually implement dynamic handling systems akin to "traditional" languages like Java.

# Detailed design

## The raising part

`error` will now take an optional expression as its right-hand side. This expression will be the value passed to the exception handler (i.e. the `else` of a `try` expression). The error value must be a subtype of `Any val`. The reasons for this are:

- The value must have a type on the handling side. `Any` is a natural choice here (because exception specifications are still static) and `val` is a compromise between the broad and not-so-useful `tag` and the very restrictive `iso`. This will allow erroring with primitives, `String`s, etc.
- This can't violate any capability boundary and avoids additional heavy checks.

An `error` with no value implicitly defaults to `error None`.

## The handling part

A new special value, `current_error`, will be accessible in the `else` branch of `try` expressions. This `current_error` will be an alias of the `error`ed value. Its type is `Any val`, the real type can be established through pattern matching to use the original value. `current_error` always references the value handled by the closest `else` block (i.e. the most nested one).

This new mechanism doesn't change anything to the actual exception handling. Exceptions still stop at the first handler encountered.

## Implementation and performance concerns

This change can be implemented with very little overhead. The cost roughly is an additional argument to a runtime function call, an additional write to memory (when raising) and an additional read from memory (when beginning handling). These operations are negligible compared to the overall cost of raising an exception.

A proof-of-concept implementation can be found [here](https://github.com/Praetonus/ponyc/tree/stateful-exceptions) (untested on Windows).

# How We Teach This

We'll update the tutorial section on exceptions to explain how to raise an error with a value and how to process that value in the handler.

We could also do a Pony Pattern explaining how to emulate a dynamic exception system on the user side through pattern matching and successive re-raising of errors.

# How We Test This

We'll add some type checking tests to ensure type validity on both the raising and the handling side. While we're currently lacking that functionnality in the test frameworks, having tests ensuring that the value is propagated correctly would be good. These tests would have to wait until we can run Pony code in JIT through the compiler and tests.

# Drawbacks

`current_error` would become a reserved identifier. Otherwise, backwards compatibility is fully maintained.

# Alternatives

- Implement a full-blown dynamic exception system. This would be a really important performance hit on most programs, while not having many advantages over the proposed system.
- Keep things as is. This would leave the concerns raised in Motivation unresolved.

# Unresolved questions

None.

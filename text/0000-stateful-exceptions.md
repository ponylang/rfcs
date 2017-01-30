- Feature Name: stateful-exceptions
- Start Date: 2017-01-27
- RFC PR:
- Pony Issue:

# Summary

Allow exceptions to carry a value from the error site to the handling site, while keeping the exception handling static. The value or its type aren't involved in destination checking. Exceptions will still land at the first handler encountered, with negligible additional runtime cost.

# Motivation

We currently have several very distinct idioms to handle errors in the language and standard library.

1. Exceptions. They are used most of the time but since they are valueless, they can't be used to propagate the reason of an error to a caller function.
2. Union types of the normal result and the error reason(s). This is used when the reason of an error is needed by a caller function (e.g. the constructors of `File` in the standard library).
3. Notifier objects that are passed-in and invoked for any errors encountered. This idiom is mostly used in actor-based asynchronous code and won't be covered here, as this RFC covers synchronous error handling.

Number 2 has several drawbacks. In particular

- The type of the result must be asserted via pattern matching, which introduces a runtime cost even in the non-erroring cases
- The error condition must be propagated manually through every calling function, unlike a "fire and forget" exception

In addition, having several different ways of doing almost the same thing isn't good for the overall consistency of the language and libraries.

Having this feature would also make the exception system a lot more versatile. By default it will still permit fast and static exception handling, while allowing programmers to manually implement dynamic handling systems akin to "traditional" languages like Java.

# Detailed design

## The raising part

`error` will now take an optional expression as its right-hand side. This expression will be the value passed to the exception handler (i.e. the `else` of a `try` expression). The error value must be a subtype of `Any val`. The reasons for this are:

- The value must have a type on the handling side. `Any` is a natural choice here (because exception specifications are still static) and `val` is a compromise between the broad and not-so-useful `tag` and the very restrictive `iso`. This will allow erroring with primitives, `String`s, etc.
- This can't violate any capability boundary and avoids additional heavy checks.

An `error` with no value implicitly defaults to `error None`.

## The handling part

A new type of `else` clause would be available to `try` expressions, the `elsematch` clause. An `elsematch` is syntactically equivalent to a standalone `match` but has no match expression and instead implicitly matches on the `error`ed value with an `Any val` type. The cases and `else` clause behave exactly like a standalone `match`. In addition, the `elsematch` can have an `elseerror` clause instead of an `else` clause. This clause "re-raises" the `error`ed value if no case matched.

The `try` expression itself can also have an `elseerror` clause instead of an `else` or `elsematch` clause. This is useful if the `try` expression also has a `then` clause, to do some cleanup but delay the actual error handling.

Example of the new syntax:

```pony
try
  partial_function()
elsematch
| ErrorType1 => foo()
| ErrorType2 => bar()
elseerror
end
```

This new mechanism doesn't change anything to the actual exception handling. Exceptions still stop at the first handler encountered.

## Implementation and performance concerns

This change can be implemented with very little overhead. The cost roughly is an additional argument to a runtime function call, an additional write to memory (when raising) and an additional read from memory (when beginning handling). These operations are negligible compared to the overall cost of raising an exception.

A proof-of-concept implementation can be found [here](https://github.com/Praetonus/ponyc/tree/stateful-exceptions) (untested on Windows).

# How We Teach This

We'll update the tutorial section on exceptions to explain how to raise an error with a value and how to process that value in the handler.

We could also do a Pony Pattern explaining how to emulate a dynamic exception system on the user side through pattern matching and successive re-raising of errors. It would also advocate for some conventions regarding the structure of the error value itself. Two conventions would be explained.

- For simple cases where the error condition can be fully described by a simple type, the error value should be a primitive. This avoids dynamic allocation and code bloat due to object initialisation. This idiom should be used through most of the standard library as most functionalities have only one way of `error`ing.
- For more complex cases, a custom `class` should be used. That `class` should contain a `SourceLoc` field initialised to `__loc` by the constructor, as well as any additional field needed to carry the error information. The `SourceLoc` field would be useful to get precise information about the error source, e.g. for logging or debugging.

# How We Test This

We'll add some type checking tests to ensure type validity on both the raising and the handling side. While we're currently lacking that functionnality in the test frameworks, having tests ensuring that the value is propagated correctly would be good. These tests would have to wait until we can run Pony code in JIT through the compiler and tests.

# Drawbacks

`elsematch` and `elseerror` would become reserved keywords. Otherwise, backwards compatibility is fully maintained.

# Alternatives

- Implement a full-blown dynamic exception system. This would be a really important performance hit on most programs, while not having many advantages over the proposed system.
- Keep things as is. This would leave the concerns raised in Motivation unresolved.

# Unresolved questions

None.

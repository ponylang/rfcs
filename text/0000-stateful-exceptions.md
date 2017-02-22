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
3. Notifier objects that are passed-in and invoked for any errors encountered. This is mostly used in asynchronous code but can also be used for local error handling recovery, for example to retry a failed operation with alternative arguments.

Number 2 has several drawbacks. In particular

- The type of the result must be asserted via pattern matching, which introduces a runtime cost even in the non-erroring cases
- The error condition must be propagated manually through every calling function, unlike a "fire and forget" exception

Number 3 doesn't have these issues but is difficult to use when the error is logically unrecoverable. For example, if one wants to open file `A` and use `stdout` if `A` isn't available, the notifier pattern can be used to default to `stdout` if opening `A` fails: the error is fully recoverable. But if the only option is to use file `A`, the error will be unrecoverable at some point of the call stack. An exception (or an error code, with the above inconvenients) must be used to skip that failed part.

Having this feature would also make the exception system a lot more versatile. By default it will still permit fast and static exception handling, while allowing programmers to manually implement dynamic handling systems akin to "traditional" languages like Java. That said, this last pattern shouldn't be the default. We should still advocate for functions with "one way to fail", and handling as close as possible to the error site. "One way to fail" here means that the method being called should intrinsically describe why it would error. The type of an error should only provide details on the reason of an error, and not carry all of the information itself. For example, a function opening a file would error when failing to open the file, with an error type describing why the file couldn't be opened.

# Detailed design

## Exception specifications

The signature of an erroring method will now specify the type that the method can possibly error with after the `?` symbol. For example:

```pony
fun foo(): ReturnType ? ErrorType
```

`ErrorType` is optional and defaults to `None` (which doesn't mean that the method cannot error, but that it can only error with type `None`).

A method that wants to error with different types can use a type union as its `ErrorType`. The only constraint on `ErrorType` is that it must be a subtype of `Any val`. This is to avoid complex issues with reference capabilities, for example with automatic receiver recovery on method calls. In subtyping relationships, error types are covariant (i.e. `{() ? A}` is a subtype of `{() ? B}` if `A` is a subtype of `B`).

### "Checked exception hell" concerns

It can be argued that exception specifications introduce a lot of complexity. Namely, the following arguments are often raised:

- Extending the exception specification of a method with a new type can cause a massive refactoring, where a new handling clause must be added everywhere the method is called.
- Exception specifications reinforce coupling. When an exception can propagate up the call stack, the associated exception specification must also be present on every method up to the handling point.

While these concerns are in some part intrinsic to checked exceptions, we'll argue here that they are amplified by bad API design and that better design, namely strict conformance to "one way to fail", can highly reduce the burden.

Having "one way to fail" means that there is always a default action to take, regardless of the details of the error. For example, if opening a file fails, printing a generic error message is a valid handling whether the file didn't exist or the user didn't have permission on it. Therefore, extending an exception signature means adding precisions about the error reason instead of adding new error reasons. This doesn't render existing handlers incorrect (unless they don't have a default case) and modifying them shouldn't be fundamentally necessary.

## The raising part

`error` will now take an optional expression as its right-hand side. This expression will be the value passed to the exception handler (i.e. the `else` of a `try` expression). The error value must be a subtype of the method's error type.

An `error` with no value implicitly defaults to `error None`.

## The handling part

A new type of `else` clause would be available to `try` expressions, the `elsematch` clause. An `elsematch` is syntactically equivalent to a standalone `match` but has no match expression and instead implicitly matches on the `error`ed value, with the match type being the union of all the types that can be errored with within the `try`. The cases and `else` clause behave exactly like a standalone `match`. In addition, the `elsematch` can have an `elseerror` clause instead of an `else` clause. This clause "re-raises" the `error`ed value if no case matched.

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

Once exhaustive pattern matching is implemented, `elsematch` should cause a compile error when an exception type isn't handled, or when a handler is unreachable.

This new mechanism doesn't change anything to the actual exception handling. Exceptions still stop at the first handler encountered.

## Implementation and performance concerns

This change can be implemented with very little overhead. The cost roughly is an additional argument to a runtime function call, an additional write to memory (when raising) and an additional read from memory (when beginning handling). These operations are negligible compared to the overall cost of raising an exception.

A proof-of-concept implementation can be found [here](https://github.com/Praetonus/ponyc/tree/stateful-exceptions) (untested on Windows). As a demonstration of the system, the `files` package was modified to use stateful exceptions. These changes aren't part of the RFC.

# How We Teach This

We'll update the tutorial section on exceptions to explain how to raise an error with a value and how to process that value in the handler.

Several conventions would have to be refined and explained.

For libraries and small applications, we should encourage users to follow "one way to fail". It is also important that we enforce strict compliance to "one way to fail" in the standard library in order to keep it modular and easy to use.

For complex application that could need such a system, we could do a Pony Pattern explaining how to emulate a dynamic exception system on the user side through pattern matching and successive re-raising of errors. It would also advocate for some conventions regarding the structure of the error value itself. Two conventions would be explained.

- For simple cases where the error condition can be fully described by a simple type, the error value should be a primitive. This avoids dynamic allocation and code bloat due to object initialisation.
- For more complex cases, a custom `class` should be used. That `class` should contain a `SourceLoc` field initialised to `__loc` by the constructor, as well as any additional field needed to carry the error information. The `SourceLoc` field would be useful to get precise information about the error source, e.g. for logging or debugging.

# How We Test This

We'll add some type checking tests to ensure type validity on both the raising and the handling side, as well as tests ensuring that the value is propagated correctly (with JIT tests).

# Drawbacks

`elsematch` and `elseerror` would become reserved keywords. Otherwise, backwards compatibility is fully maintained.

# Alternatives

- Implement a full-blown dynamic exception system. This would be a really important performance hit on most programs, while not having many advantages over the proposed system.
- Keep things as is. This would leave the concerns raised in Motivation unresolved.

# Unresolved questions

None.

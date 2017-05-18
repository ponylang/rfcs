- Feature Name: string-concatenation
- Start Date: 2017-05-17
- RFC PR:
- Pony Issue:

# Summary

A new syntax for concatenating `String`s (and `Stringable`s) that generates efficient code for creating the final `String`.

# Motivation

When writing code, what often comes most naturally (and succinctly) is to concatenate `String`s together using the `add` method sugar, as in this modified example from the standard library:

```pony
primitive DefaultLogFormatter is LogFormatter
  fun apply(msg: String, loc: SourceLoc): String =>
    loc.file() + ":" + loc.line().string() + ":" + loc.pos().string() + ": " + msg
```

However, this approach is not very performant, for the reasons explained in the Pony Pattern named ["Limiting String Allocations"](https://github.com/ponylang/pony-patterns/blob/master/performance/limiting-string-allocations.md). For those reasons, the *actual* standard library example looks like this:

```pony
primitive DefaultLogFormatter is LogFormatter
  fun apply(msg: String, loc: SourceLoc): String =>
    let file_name: String = loc.file()
    let file_linenum: String  = loc.line().string()
    let file_linepos: String  = loc.pos().string()

    let output = recover String(file_name.size()
    + file_linenum.size()
    + file_linepos.size()
    + msg.size()
    + 4) end

    output.append(file_name)
    output.append(":")
    output.append(file_linenum)
    output.append(":")
    output.append(file_linepos)
    output.append(": ")
    output.append(msg)
    output
```

This pattern is far more verbose and cumbersome, so will only likely be used when users are *very* concerned about performance, rather than being used by default as the most common way of concatenating strings.

Part of the appeal of Pony is that often the most natural way to do something in the language is also very performant. This is not currently true of string concatenation.

# Detailed design

A new symbol will be added to Pony syntax that represents string concatenation, allowing use like the following:

```pony
primitive DefaultLogFormatter is LogFormatter
  fun apply(msg: String, loc: SourceLoc): String =>
    loc.file() <> ":" <> loc.line() <> ":" <> loc.pos() <> ": " <> msg
```

This syntax would translate to the same code as the long-form example above, where any non-`String` operands are converted to `String`s via their respective `string` methods, the total byte size of all operands is calculated to allocate an appropriately-sized `String` for the final buffer, and all operands are appended to the final buffer.

The compiler may even be able to do some additional optimization, such as using `push` calls instead of `append` for very short string literals in a concatenation.

All operands in a string concatenation must be a `String`, or be a type that has a `string` method that takes no arguments. The `String` for each operand (or the return type of their `string` method) must be readable (that is, it must be a subtype of `String box`).

The `string` method will not be called more than once for each operand, and it will not be called at all if the operand is already a `String`.

The result type of a string concatenation expression containing any non-literal operands will be `String iso^`, as if it had all been in a `recover` block.

As a special case, if all the operands of a string concatenation expression are string literals, they will be implicitly joined as a single string literal, with a result type of `String val` (just like any other string literal). This lets users use string concatenation as a way to break up a string literal over multiple lines, without incurring an allocation/copy penalty every time the expression is executed.

The `<>` symbol will be compiler sugar for this specific construct, thus it will not be available for "operator overloading" by defining a custom method on a type, as some other operators are.

This syntax would make `String.add` obsolete, and keeping it around would be confusing to users, as we would have two ways of doing the same thing, with one way being dramatically less performant. Thus, the `String.add` method would be removed to prompt users to adopt the new syntax for superior performance.

# How We Teach This

The string concatenation syntax should be mentioned in the tutorial, and in the Pony Pattern named ["Limiting String Allocations"](https://github.com/ponylang/pony-patterns/blob/master/performance/limiting-string-allocations.md). The Pony Pattern will still need to explain the explicit allocate-then-`append` approach, since it will still be necessary to use the long form in some cases not covered by the new syntax, such as when calling `append` from inside a loop while iterating over a dynamically-sized list of constituent parts.

All string concatenation in the standard library and examples should be updated to use the new syntax where applicable.

# How We Test This

Compiler unit tests will be written to a variety of cases for string concatenation.

# Drawbacks

* Additional compiler complexity, in the form of new AST tokens, new parser rules, and new sugar logic in the `expr` pass.

# Alternatives

* Don't change anything, and continue to leave it up to the user to choose between brevity and performance when doing string concatenation.
* Choose a different symbol for the concatenation expressions.
* Choose to use an "embedded" style of syntax, more reminiscent of string *interpolation*, such as `"${loc.file()}:${loc.line()}:${loc.pos()}:${msg}"`. This idea was abandoned because I'm not sure it can be made to work with our LL(1) parser/grammar. Even if it is possible, the infix symbol is much more straightforward to parse.

# Unresolved questions

* None.

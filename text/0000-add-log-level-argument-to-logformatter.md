- Feature Name: add-log-level-argument-to-logformatter
- Start Date: 2020-06-07
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Add a `log_level` argument to logger.LogFormatter.

# Motivation

In an attempt to replace Corral's custom logging facilities with the standard
library logger, it was discovered that prepending the log level to log messages
would be much easier if the log level was exposed in LogFormatter.apply().

# Detailed design

- Add a `log_level` argument with type `LogLevel` to `LogFormatter.apply()`, in the first position
- Have all subtypes of `LogLevel` implement the `Stringable` interface
- Change `Logger.log` to add the `_level` field as an argument to `_formatter.apply()`
- Change `DefaultLogFormatter.apply()` to accept (and ignore) the new `log_level`
  argument.

# How We Teach This

This RFC could be announced as a note in last week in Pony. If the RFC is
accepted and subsequently implemented, the addition of the new argument to
`LogFormatter.apply()` could be announced as a breaking change in the release
notes of a new release of ponyc.

Upon upgrading to the new release of ponyc, users will be faced with
compile-time errors if their code contains implementations of the old
`LogFormatter` interface.

# How We Test This

- CI should pass for the ponyc repo after the changes are implemented.
- The test suite for the logger package has its own implementation of
LogFormatter that will have to change as the LogFormatter interface changes.
- A unit test could be added that uses an implementation of LogFormatter that
prints the `log_level` argument. The unit test could then assert that the proper
message is printed.

# Drawbacks

- Breaks all implementations of LogFormatter in the wild. For many LogFormatters, the fix will be trivial; adding and ignoring the new `log_level` argument.

# Alternatives

The same behavior could be achieved by some function that accepts a LogLevel and
a String and produces a new String that would be then passed to
LogFormatter.apply(). Any user wishing to have LogFormatter behavior that
branches on log level might have to do something similar in their own code. Here
is an example:

```pony
use "logger"

primitive LogMsg is LogFormatter
  fun apply(lvl: LogLevel, s: String): String =>
    match lvl
    | Fine => "FINE"
    | Info => "INFO"
    | Warn => "WARN"
    | Error => "ERRR"
    end
    lvl + ": " + s

actor Main
  new create(env: Env) =>
    let logger = StringLogger(Info, env.out)
    logger.log(LogMsg(Info, "foo")) // prints "INFO: foo"
```

# Unresolved questions

- Would it be good to add a `string()` method to the primitives that comprise
  LogLevel? This could save a possible match expression in implementations of
  LogFormatter that want some default string representation of the log level.

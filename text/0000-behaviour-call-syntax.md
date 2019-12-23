- Feature Name: behaviour_call_syntax
- Start Date: 2019-12-22
- RFC PR:
- Pony Issue:

# Summary

Modify the language to differentiate between synchronous function calls and asynchronous behaviour calls at the call site.

# Motivation

A call site distinction between functions and behaviours on an actor would give the reader a more clear view of the program's execution. The current use of `.` notation for both function and behaviour calls has lead to at least some confusion to new Pony users, who may be more accustomed to the message send syntax of Erlang or Akka. The motivation behind this change is similar to that of explicit partial calls, in that the reader could more easily notice that a behaviour call will be executed asynchronously with the rest of the function body.

# Detailed design

A new syntax of `a~b()` is used for calling a behaviour (`b`) on an actor (`a`). The previous notation of `a.b()` will now only be allowed at a function call site.

As an example, the following `TCPConnectionNotify` has its `received` function executed within a `TCPConnection` behaviour. In this example, "stuff" will never be written if "done" has been received. This is because `conn~write("things")` is called as a behaviour and `conn.close()` is called as a function. Using the new syntax, it is immediately obvious that the execution of `write` is not occurring in-line with the rest of the function body.
```pony
use "net"

class MyNotify is TCPConnectionNotify
  let _out: OutStream

  new iso create(out: OutStream) =>
    _out = out

  fun ref connect_failed(conn: TCPConnection ref) =>
    None

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize)
    : Bool
  =>
    conn~write("stuff")

    if String.from_iso_array(consume data) == "done" then
      conn.close()
    end

    false

actor Main
  new create(env: Env) =>
    try
      TCPConnection(env.root as AmbientAuth, MyNotify(env.out), "", "8989")
    end
```

# How We Teach This

Updates to the Pony Tutorial, Patterns, etc. would be necessary to reflect the new syntax on all behaviour calls.

A script will also be provided to migrate existing pony code (as done for [explicit partial calls](https://github.com/ponylang/rfcs/blob/master/text/0039-explicit-partial-calls.md)).

# How We Test This

This would be tested through the update of compiler tests, the standard library, and other existing pony code impacted by this change.

# Drawbacks

This would be a major breaking change, and would likely break most existing Pony code.

# Alternatives

Alternative operator for async call syntax (currently `~`) that doesn't conflict with the [partial applications](https://tutorial.ponylang.io/expressions/partial-application.html).

# Unresolved questions

- How should partial application syntax be modified to support this change? I believe that behaviour calls are much more common than partial application, and should therefore take the more "understandable" and terse syntax. But this is very subjective and suggestions for alternative syntax for either are welcome.

- Should apply sugar still be allowed for actors? If so, we would have to differentiate behaviour calls with something like `a~()`. For reference, here is a list of all public actors in the stdlib with `apply` behaviours:
  - `builtin.InputStream`
  - `builtin.Stdin`
  - `bureaucracy.Custodian`
  - `ponybench.PonyBench`
  - `ponytest.PonyTest`
  - `promises.Promise`
  - `term.ANSITerm`
  - `time.Timers`

- May any actor function with sendable parameters be called, using the new syntax, as behaviours? If so, any return type on the function would become `None` when called this way.

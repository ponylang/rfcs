- Feature Name: redesign-signal-handling
- Start Date: 2026-02-27
- RFC PR:
- Pony Issue:

# Summary

Redesign signal handling to use a centralized dispatch mechanism with capability security and support for multiple subscribers per signal. The current implementation has inconsistent cross-platform behavior and lacks the auth requirements that other I/O primitives in the standard library have.

# Motivation

Pony's current signal handling has several problems, documented in [ponylang/rfcs#170](https://github.com/ponylang/rfcs/issues/170):

**Inconsistent cross-platform behavior.** On macOS (kqueue), registering a second handler for the same signal replaces the first — the last handler wins. On Linux (epoll), the first handler wins and subsequent registrations are silently ignored. This means the same program produces different behavior on different platforms, which violates Pony's goal of consistent cross-platform semantics.

**No capability security.** Every other I/O primitive in the standard library — TCP, UDP, files — requires an auth token derived from `AmbientAuth`. Signal handling does not. Any code with access to the `signals` package can register handlers or raise signals without any capability check. This is inconsistent with how Pony handles other system resources.

**Silent failure with multiple handlers.** There is no way to register multiple handlers for the same signal. On Linux, additional handlers are silently ignored. On macOS, they silently replace the previous handler. Neither platform gives the user any feedback that their handler isn't working as expected.

**The runtime already owns the OS signal handler.** The ASIO subsystem already intercepts signals at the OS level and dispatches them to Pony actors. The infrastructure for centralized dispatch exists — it just doesn't support fanning out to multiple subscribers.

# Detailed design

## New auth type: `SignalAuth`

A new auth primitive, following the same pattern as `TCPAuth`, `UDPAuth`, etc.:

```pony
primitive SignalAuth
  new create(from: AmbientAuth) =>
    None
```

`SignalAuth` is derived directly from `AmbientAuth`. There is no intermediate `NetAuth`-style grouping — signals are a distinct resource category.

## Updated `SignalHandler`

The `SignalHandler` actor gains a required `SignalAuth` parameter:

```pony
actor SignalHandler is AsioEventNotify
  """
  Listen for a specific signal.

  Multiple SignalHandlers can be registered for the same signal. All
  registered handlers will be notified when the signal is received, in
  no particular order.

  If the wait parameter is true, the program will not terminate until
  the SignalHandler's dispose method is called, or if the SignalNotify
  returns false after handling the signal. Disposing a SignalHandler
  unsubscribes it from the signal and is required to allow the runtime
  to garbage collect the handler.
  """

  new create(auth: SignalAuth, notify: SignalNotify iso, sig: U32,
    wait: Bool = false)
  =>
    """
    Create a signal handler.
    """

  be raise(auth: SignalAuth) =>
    """
    Raise the signal.
    """

  be dispose(auth: SignalAuth) =>
    """
    Dispose of the signal handler, unsubscribing from the signal.
    """
```

The key changes:

- `auth: SignalAuth` is now the first parameter to the constructor.
- The runtime maintains a list of subscribers for each signal number. When a signal arrives, all subscribers are notified with the signal count. The order of notification is undefined.
- `dispose()` removes this handler from the subscriber list. This is important because the signal dispatch mechanism holds a reference to each subscriber — without explicit disposal, handlers will never be garbage collected.
- `raise()` and `dispose()` both require `SignalAuth` because any actor with a reference to the handler can send these messages — auth gates the operations themselves, not just construction.

## `SignalNotify` interface

The `SignalNotify` interface is unchanged:

```pony
interface SignalNotify
  fun ref apply(count: U32): Bool =>
    """
    Called with the number of times the signal has fired since this was
    last called. Return false to stop listening for the signal.
    """
    true

  fun ref dispose() =>
    """
    Called if the signal is disposed. This is also called if the notifier
    returns false.
    """
    None
```

## Updated `SignalRaise`

`SignalRaise` also requires auth:

```pony
primitive SignalRaise
  """
  Raise a signal.
  """
  fun apply(auth: SignalAuth, sig: U32) =>
    ifdef osx then
      // On Darwin, @raise delivers the signal to the current thread, not the
      // process, but kqueue EVFILT_SIGNAL will only see signals delivered to
      // the process. @kill delivers the signal to a specific process.
      @kill(@getpid(), sig)
    else
      @raise(sig)
    end
```

## `Sig` primitive

The `Sig` primitive is unchanged. It provides portable signal number constants and has no security implications.

## Runtime changes

The ASIO subsystem needs to change how it tracks signal subscriptions. Currently, each signal maps to at most one ASIO event. The new design maintains a list of ASIO events per signal number. When a signal fires, the runtime iterates over the list and notifies all subscribers. When a handler is disposed, its event is removed from the list. When the last subscriber for a signal is removed, the signal disposition is restored to the default OS behavior.

The order of notification across subscribers is explicitly undefined. This avoids creating implicit dependencies between handlers and gives the runtime freedom to use whatever data structure is most efficient.

The subscriber list must be safe to read from signal handler context. The current implementation uses atomic operations on a single-slot array; a multi-subscriber list will need equivalent care. The specific synchronization strategy is left to the implementer.

The IOCP backend on Windows has signal handling support using the C `signal()` function. The multi-subscriber changes described here would need to be applied to the IOCP backend as well, following the same design.

## Usage example

```pony
use "signals"

actor Main
  new create(env: Env) =>
    let auth = SignalAuth(env.root)

    // Multiple handlers for the same signal
    SignalHandler(auth, LogHandler(env.out), Sig.term())
    SignalHandler(auth, CleanupHandler(env.out), Sig.term() where wait = true)

class LogHandler is SignalNotify
  let _out: OutStream

  new iso create(out: OutStream) =>
    _out = out

  fun ref apply(count: U32): Bool =>
    _out.print("Signal received, count: " + count.string())
    true

class CleanupHandler is SignalNotify
  let _out: OutStream

  new iso create(out: OutStream) =>
    _out = out

  fun ref apply(count: U32): Bool =>
    _out.print("Cleaning up...")
    // Return false to stop listening and dispose the handler
    false

  fun ref dispose() =>
    _out.print("Cleanup handler disposed")
```

## Fatal signals

Fatal signals (SIGFPE, SIGILL, SIGSEGV, SIGABRT) are explicitly out of scope for this RFC. The ASIO event mechanism is not suitable for handling fatal signals because the process may be in an undefined state when they fire. Users who need to handle fatal signals should use FFI to register C-level signal handlers directly.

# How We Teach This

The `signals` package documentation should include:

- A package-level docstring explaining the subscription model and the requirement for auth, with a complete usage example.
- Docstrings on `SignalHandler` explaining multi-subscriber semantics and the importance of disposing handlers.
- Docstrings on `SignalAuth` explaining its role in capability security, consistent with how `TCPAuth`/`UDPAuth` are documented.

The release notes for the version containing this change should call out the breaking change to `SignalHandler` and `SignalRaise` constructors and provide a migration example showing the before and after.

# How We Test This

- Unit tests for basic subscribe and receive: register a handler, raise the signal, verify the handler is called.
- Unit tests for multiple handlers: register two handlers for the same signal, raise the signal, verify both are called.
- Unit tests for dispose: register a handler, dispose it, raise the signal, verify the handler is not called.
- Unit tests for `SignalNotify` returning false: verify that returning false from `apply` disposes the handler and stops notification.
- CI runs on both Linux and macOS, which will verify that the behavior is consistent across platforms — the primary bug this RFC fixes.

# Drawbacks

This is a breaking change. All existing code that creates a `SignalHandler` or calls `SignalRaise` will need to be updated to pass a `SignalAuth` parameter. However, the migration is mechanical — add `SignalAuth(env.root)` at the point where signals are set up and thread it through.

# Alternatives

## Remove signals from stdlib entirely

The current signal abstraction is broken enough to warrant considering whether it should exist in the standard library at all. Signals are an inherently Unix concept with platform-specific edge cases. Users who need signal handling could use FFI to call the C signal APIs directly, giving them full control over the behavior.

The argument against removal is that signal handling is common enough that having a safe, capability-secured abstraction in the standard library is valuable. Without it, every user writes their own FFI bindings, likely reproducing the same platform inconsistencies that this RFC fixes.

## Keep current behavior and document it

We could keep the existing single-handler-per-signal behavior and simply document that registering multiple handlers is not supported. This avoids the breaking change but doesn't fix the platform inconsistency (first-wins vs last-wins) and doesn't add capability security. It would also mean the signals package remains the only I/O primitive without auth requirements.

# Unresolved questions

None at this time. The core design decisions — centralized dispatch, auth requirement, multiple subscribers, undefined notification order, fatal signals out of scope — have been discussed and agreed upon. Implementation details such as the internal data structure for subscriber lists are left to the implementer.

- Feature Name: redesign-signal-handling
- Start Date: 2026-02-27
- RFC PR: https://github.com/ponylang/rfcs/pull/220
- Pony Issue: https://github.com/ponylang/ponyc/issues/5793

# Summary

Redesign signal handling to use a centralized dispatch mechanism with capability security, validated signal types, support for multiple subscribers per signal, and explicit reporting when a registration fails. The current implementation has inconsistent cross-platform behavior, lacks the auth requirements that other I/O primitives in the standard library have, and allows registration of handlers for fatal signals that cannot be meaningfully handled.

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

## Handleable signal type: `HandleableSignal`

A constrained type that only permits handleable signals. Fatal signals (SIGILL, SIGTRAP, SIGABRT, SIGFPE, SIGBUS, SIGSEGV) and uncatchable signals (SIGKILL, SIGSTOP) are rejected by the validator.

```pony
use "constrained_types"

primitive HandleableSignalValidator is Validator[U32]
  """
  Validates that a signal number is handleable via the ASIO mechanism.
  Only signals that can be safely caught and dispatched to Pony actors
  are accepted. Fatal and uncatchable signals are rejected. SIGUSR2 is
  accepted only on `scheduler_scaling_pthreads` builds, where the runtime
  leaves it free; on other builds `Sig.usr2()` is a compile error.
  """
  fun apply(sig: U32): ValidationResult =>
    if _is_handleable(sig) then
      ValidationSuccess
    else
      recover val
        ValidationFailure(sig.string() + " is not a handleable signal")
      end
    end

  fun _usr2_handleable(sig: U32): Bool =>
    // SIGUSR2 is free only on scheduler_scaling_pthreads builds; on other
    // builds the runtime reserves it and `Sig.usr2()` is a compile error.
    // This gate must match `Sig.usr2()`'s in the `Sig` primitive.
    ifdef "scheduler_scaling_pthreads" and not windows then
      sig == Sig.usr2()
    else
      false
    end

  fun _is_handleable(sig: U32): Bool =>
    // Whitelist: only signals that can be meaningfully handled.
    // Each branch covers the handleable signals for that platform.
    ifdef bsd or osx then
      (sig == Sig.hup()) or (sig == Sig.int()) or (sig == Sig.quit())
        or (sig == Sig.emt()) or (sig == Sig.pipe()) or (sig == Sig.alrm())
        or (sig == Sig.term()) or (sig == Sig.urg()) or (sig == Sig.tstp())
        or (sig == Sig.cont()) or (sig == Sig.chld()) or (sig == Sig.ttin())
        or (sig == Sig.ttou()) or (sig == Sig.io()) or (sig == Sig.xcpu())
        or (sig == Sig.xfsz()) or (sig == Sig.vtalrm()) or (sig == Sig.prof())
        or (sig == Sig.winch()) or (sig == Sig.info()) or (sig == Sig.usr1())
        or (sig == Sig.sys())
        or _usr2_handleable(sig)
        or _is_rt(sig)
    elseif linux then
      (sig == Sig.hup()) or (sig == Sig.int()) or (sig == Sig.quit())
        or (sig == Sig.pipe()) or (sig == Sig.alrm()) or (sig == Sig.term())
        or (sig == Sig.urg()) or (sig == Sig.stkflt()) or (sig == Sig.tstp())
        or (sig == Sig.cont()) or (sig == Sig.chld()) or (sig == Sig.ttin())
        or (sig == Sig.ttou()) or (sig == Sig.io()) or (sig == Sig.xcpu())
        or (sig == Sig.xfsz()) or (sig == Sig.vtalrm()) or (sig == Sig.prof())
        or (sig == Sig.winch()) or (sig == Sig.pwr()) or (sig == Sig.usr1())
        or (sig == Sig.sys())
        or _usr2_handleable(sig)
        or _is_rt(sig)
    elseif windows then
      (sig == Sig.int()) or (sig == Sig.term())
    else
      false
    end

  fun _is_rt(sig: U32): Bool =>
    ifdef bsd then
      (sig >= 65) and (sig <= 126)
    elseif linux then
      (sig >= 32) and (sig <= 64)
    else
      false
    end

type HandleableSignal is Constrained[U32, HandleableSignalValidator]
type MakeHandleableSignal is MakeConstrained[U32, HandleableSignalValidator]
```

The validator uses a whitelist — only known handleable signals pass validation. Unknown or arbitrary signal numbers are rejected by default. Each platform branch lists exactly the signals from the `Sig` primitive that are safe to handle via the ASIO mechanism. Real-time signals are validated by range. On Windows, only SIGINT and SIGTERM can be meaningfully handled through the ASIO mechanism; the other signals the CRT defines (SIGABRT, SIGFPE, SIGILL, SIGSEGV) are synchronous or fatal there.

SIGUSR2 is handleable only on `scheduler_scaling_pthreads` builds. On default builds the runtime reserves it for scheduler sleep/wake and consumes it with `sigwait`, so a handler would never fire — and there `Sig.usr2()` is a compile error, so the number can never reach the validator. On `scheduler_scaling_pthreads` builds (forced on macOS) the scheduler uses condition variables instead and leaves SIGUSR2 free, so `Sig.usr2()` yields a number and the validator accepts it. The `_usr2_handleable` branch gates on the same build flag as `Sig.usr2()`, so the validator admits SIGUSR2 exactly where the runtime has left it free.

Validation is necessary but not sufficient. The operating system can refuse a registration the whitelist admits (glibc reserves the two lowest real-time signals for its threading internals, musl the three lowest), and diagnostic `use=runtime_tracing` builds reserve a pause signal of their own (SIGRTMIN on Linux, SIGINFO on BSD and macOS). An OS-level refusal surfaces through the failure path described under `SignalNotify` below: the notify's `registration_failed` is called and the handler is automatically disposed.

## Updated `SignalHandler`

The `SignalHandler` actor gains required `SignalAuth` and `HandleableSignal` parameters:

```pony
actor SignalHandler is AsioEventNotify
  """
  Listen for a specific signal.

  Multiple SignalHandlers can be registered for the same signal — up to 16
  per signal number. All registered handlers will be notified when the
  signal is received, in no particular order. If a handler cannot be
  registered (the 16-subscriber limit is reached, or the runtime fails to
  register with the operating system), its notify's `registration_failed`
  is called with the reason and the handler is automatically disposed;
  `apply` will not have run.

  If the wait parameter is true, the program will not terminate until
  the SignalHandler's dispose method is called or the SignalNotify
  returns false after handling the signal. Disposing a SignalHandler
  unsubscribes it from the signal and is required to allow the runtime
  to garbage collect the handler.
  """

  new create(auth: SignalAuth, notify: SignalNotify iso, sig: HandleableSignal,
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
- `sig` is now `HandleableSignal` instead of `U32`. Fatal and uncatchable signals cannot be registered — the constrained type prevents construction with those signal numbers.
- The runtime maintains a table of subscribers for each signal number, capped at 16. When a signal arrives, all subscribers are notified with the signal count. The order of notification is undefined.
- A handler that cannot be registered (the 16-subscriber limit is reached, or the operating system refuses the registration) has the failure reported through the notify's `registration_failed` and is automatically disposed. Its `apply` will not have run.
- Registration completes inside the constructor. Once the constructor has run, the OS handler and the subscription are active, so a `raise()` sent immediately after creating a handler cannot be lost to a registration race. The runtime's synchronous registration provides this guarantee (see Runtime changes).
- A raise is process-wide: every current subscriber for the signal is notified, not just the handler it was sent through. If no handler is subscribed when the signal is delivered, the operating system's default disposition applies — for most terminating signals, process death.
- `dispose()` removes this handler from the subscriber table. This is important because the signal dispatch mechanism holds a reference to each subscriber — without explicit disposal, handlers will never be garbage collected.
- `raise()` and `dispose()` both require `SignalAuth` because any actor with a reference to the handler can send these messages — auth gates the operations themselves, not just construction.
- Because `dispose()` takes a parameter, `SignalHandler` no longer satisfies interfaces that require a parameterless `dispose`, such as `DisposableActor` — a `bureaucracy.Custodian` can no longer dispose a `SignalHandler` directly.

## `SignalNotify` interface

`SignalNotify` gains a failure callback. Registration can now fail (the 16-subscriber limit, or an OS-level refusal), and a failure reported only through `disposed()` would be indistinguishable from ordinary disposal. The rest of the standard library gives acquisition failure a dedicated callback (`TCPListenNotify.not_listening`, `TCPConnectionNotify.connect_failed`); signals now do the same:

```pony
primitive SignalSubscriberLimit
  """
  The per-signal subscriber limit (16) was already reached. A later
  registration for the same signal can succeed once a current subscriber
  unsubscribes.
  """

primitive SignalRegistrationRefused
  """
  The operating system refused the registration. Retrying will not
  succeed.
  """

type SignalRegistrationError is
  (SignalSubscriberLimit | SignalRegistrationRefused)

interface SignalNotify
  fun ref apply(count: U32): Bool =>
    """
    Called with the number of times the signal has fired since this was
    last called. Return false to stop listening for the signal.
    """
    true

  fun ref registration_failed(reason: SignalRegistrationError) =>
    """
    Called when the handler's registration could not be completed. The
    handler is then disposed — `disposed` follows once the runtime
    confirms it, and `apply` will not have run. If the handler was
    explicitly disposed before the failure was delivered, only `disposed`
    is called.
    """
    None

  fun ref disposed() =>
    """
    Called when the runtime has finished unregistering the handler,
    whichever way disposal began: explicitly via `SignalHandler.dispose`,
    when `apply` returned false, or when the registration could not be
    completed (preceded by `registration_failed` in that case). `apply`
    will never be called after this.
    """
    None
```

`registration_failed` takes a closed-union reason rather than no argument because the two causes call for different responses: the subscriber limit is transient (a slot opens when another handler unsubscribes), while an OS refusal is permanent, and retrying on it loops forever. The reason has to ship with the callback: adding a parameter to an interface method later breaks every existing overrider.

`registration_failed` runs before `disposed` instead of replacing it, so `disposed` stays the single end-of-life callback — it is called no matter how the handler ended. The method has a default empty body, so classes declaring `is SignalNotify` are unaffected; a class conforming to the interface only structurally must add the method or declare `is SignalNotify`, since default bodies don't count toward structural subtyping.

The callback is named `disposed` — past tense, matching the event vocabulary of `TCPConnectionNotify.closed` and `connect_failed` — and it reports completion, not the request: it fires once the runtime has finished unregistering the handler, not when disposal was asked for. The requester already knows the request happened; what only the runtime can say is when the work is done, and for signals that moment is observable process state — once the last subscriber's teardown commits, the signal takes the operating system's default disposition again. Reporting completion is what lets a program dispose a SIGTERM handler and then re-raise the signal from the callback so the process ends the way an unhandled signal ends it on that platform. An earlier draft fired the callback (then named `dispose`) at request time, which carried no information the caller didn't already have. One consequence of reporting completion: a handler disposed while the runtime itself is shutting down may never receive the callback, since the confirmation is dropped when the process is already exiting.

Undisposed handlers are cleaned up at runtime shutdown. A `wait = false` handler doesn't keep the program alive and doesn't need to be disposed, so a program can reach shutdown with signals still registered — and the process's disposition for those signals points into runtime state that is about to be freed, where a late signal could crash the process ([ponylang/ponyc#5564](https://github.com/ponylang/ponyc/issues/5564)). The runtime restores the operating system's default disposition for every still-registered signal on its way out, and a signal that arrives while the teardown is committing is dropped.

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

The `Sig` primitive keeps its accessors unchanged — it provides portable signal number constants and has no security implications. Its docstring now notes that numbers outside the accessors can still be raised, while handling a signal requires its number to pass `MakeHandleableSignal`.

## Runtime changes

### Current architecture

Each ASIO backend stores at most one `asio_event_t*` per signal number:

- **epoll (Linux):** `PONY_ATOMIC(asio_event_t*) sighandlers[128]` — a fixed-size array indexed by signal number. Registration uses `atomic_compare_exchange_strong` with acquire-release ordering; if the slot is non-NULL, the registration silently fails. Each registered signal gets its own `eventfd`. The C signal handler does `eventfd_write(ev->fd, 1)` to notify the ASIO thread, which reads the accumulated count and sends an `asio_msg_t` to the owning actor.
- **kqueue (macOS/BSD):** No signal handler array. Each signal is registered as a `EVFILT_SIGNAL` kevent with the subscriber's `asio_event_t*` stored as `udata`. Using `EV_ADD` with the same signal identifier replaces the `udata`, so the last registration wins. The kernel delivers the signal count directly via the kevent's `data` field.
- **Windows readiness backend (sock_notify.c):** `asio_event_t* sighandlers[32]` — a non-atomic array, safe because all modifications are serialized through the ASIO thread's request queue (`ASIO_SET_SIGNAL` / `ASIO_CANCEL_SIGNAL`). The CRT signal handler posts the signal number to the completion port; the ASIO thread sends the event. Windows `signal()` is one-shot, so the handler re-registers itself on each invocation. (Since this RFC was first drafted, [ponylang/ponyc#5556](https://github.com/ponylang/ponyc/pull/5556) replaced the IOCP socket backend with this one; the signal machinery kept the same shape.)

### Required changes

The single-slot-per-signal design must change to a table of subscribers per signal number. The key constraint is that the C signal handler runs in signal context (async-signal-safe calls only), so the fan-out to multiple subscribers should happen in the ASIO thread, not in the signal handler itself.

**Signal handler (C level):** The C signal handler's job stays minimal — it signals that a particular signal number fired. On Linux, it writes to a single eventfd per signal number (not per subscriber). On macOS, the kernel delivers the kevent. On Windows, it posts the signal number to the completion port. The C signal handler does not need to know how many subscribers exist.

**Subscriber table:** Each backend replaces its single `asio_event_t*` per signal with a fixed table of 16 subscriber slots plus a registration state. On Linux, the structure also holds the shared eventfd — the C signal handler writes to it once, and the ASIO thread fans out. The cap is documented API behavior: the 17th subscriber for a signal is rejected, and the rejection is reported through `registration_failed(SignalSubscriberLimit)`.

**Fan-out in the ASIO thread:** When the ASIO thread detects that a signal fired (via epoll readiness on the eventfd, a kevent with `EVFILT_SIGNAL`, or a completion-port packet), it determines the delivery count (the accumulated count on Linux and macOS; one per completion packet on Windows) and iterates the subscriber slots for that signal, calling `pony_asio_event_send(ev, ASIO_SIGNAL, count)` for each subscriber. The order of iteration is undefined.

**Registration:** Registration is synchronous on the subscribing scheduler thread, on all backends, using an atomic compare-and-swap protocol: the first subscriber claims the registration state, installs the OS handler, and publishes; later subscribers insert into a free slot and re-verify the state, retrying if a concurrent teardown raced them. Synchronous registration is what makes the API's ordering guarantee possible — a handler's subscription is active before its constructor finishes, so `handler.raise(auth)` sent right after creating the handler cannot fire before the handler is registered. (An earlier draft of this RFC serialized registration through the ASIO thread's request queue; that design cannot give the guarantee, because the raise can reach the operating system before the queued registration is processed.) Registration failures (the OS refusing the handler install, or a full subscriber table) are reported to the subscribing event with the failure reason and surface as `registration_failed` plus automatic disposal.

**Unregistration:** Unregistration stays serialized through the ASIO thread's request queue on all backends. When the last subscriber for a signal unsubscribes, the ASIO thread claims the registration, re-checks for a racing subscriber, and on commit restores `SIG_DFL` and tears down the notification channel (closing the shared eventfd on Linux, deleting the kevent on macOS/BSD, restoring the CRT disposition on Windows).

## Usage example

```pony
use "constrained_types"
use "signals"

actor Main
  new create(env: Env) =>
    let auth = SignalAuth(env.root)

    // Validate the signal number at the boundary
    match MakeHandleableSignal(Sig.term())
    | let sig: HandleableSignal =>
      // Multiple handlers for the same signal
      SignalHandler(auth, LogHandler(env.out), sig)
      SignalHandler(auth, CleanupHandler(env.out), sig where wait = true)
    | let _: ValidationFailure =>
      env.err.print("Cannot handle this signal")
    end

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

  fun ref disposed() =>
    _out.print("Cleanup handler disposed")
```

## Fatal and uncatchable signals

Fatal signals (SIGILL, SIGTRAP, SIGABRT, SIGFPE, SIGBUS, SIGSEGV) and uncatchable signals (SIGKILL, SIGSTOP) cannot be registered with `SignalHandler`. The `HandleableSignalValidator` rejects them at the type boundary — a `HandleableSignal` can never contain one of these signal numbers.

The ASIO event mechanism is not suitable for fatal signals because the process may be in an undefined state when they fire. SIGKILL and SIGSTOP cannot be caught at the OS level. Users who need to handle fatal signals should use FFI to register C-level signal handlers directly.

Note that `SignalRaise` still accepts raw `U32` values and does not use `HandleableSignal`. Raising a fatal signal (e.g., SIGABRT to intentionally crash) is a legitimate operation — it is only *handling* them via the ASIO mechanism that is prevented.

# How We Teach This

The `signals` package documentation should include:

- A package-level docstring explaining the subscription model, the requirement for auth, and the use of `HandleableSignal` to prevent registration of fatal signals, with a complete usage example.
- Docstrings on `SignalHandler` explaining multi-subscriber semantics and the importance of disposing handlers.
- Docstrings on `SignalAuth` explaining its role in capability security, consistent with how `TCPAuth`/`UDPAuth` are documented.
- Docstrings on `HandleableSignalValidator` explaining which signals are accepted, why fatal and uncatchable signals are rejected, and how SIGUSR2 is handleable only on `scheduler_scaling_pthreads` builds.
- Docstrings on `SignalNotify.registration_failed` explaining the two failure reasons and that the transient one (the subscriber limit) is the only one worth retrying.

The release notes for the version containing this change should call out the breaking changes to `SignalHandler` and `SignalRaise` and the loss of `DisposableActor` conformance (with a replacement pattern for `Custodian` users), and provide a migration example showing the before and after.

# How We Test This

- Validator tests: verify that all handleable signals pass `HandleableSignalValidator` and that all fatal signals (ill, trap, abrt, fpe, bus, segv) and uncatchable signals (kill, stop) are rejected.
- Unit tests for basic subscribe and receive: register a handler, raise the signal, verify the handler is called.
- Unit tests for multiple handlers: register two handlers for the same signal, raise the signal, verify both are called.
- Unit tests for dispose: register a handler, dispose it, raise the signal, verify the handler is not called.
- A disposition-restore test: dispose a signal's last handler and, from the notify's `disposed` callback, read the disposition back via FFI to verify the operating system's default was restored — `disposed` reporting completion is what makes this deterministic.
- Unit tests for `SignalNotify` returning false: verify that returning false from `apply` disposes the handler and stops notification.
- A subscriber-limit boundary test: 16 handlers register and all receive the signal; the 17th gets `registration_failed(SignalSubscriberLimit)` and is disposed without ever receiving `apply`; disposing a subscriber frees its slot for a later handler.
- Boundary tests pinning the real-time signal ranges from both sides, and a SIGUSR2 delivery test that runs only on `scheduler_scaling_pthreads` builds (macOS CI), where the runtime leaves the signal free.
- An OS-refusal test: glibc and musl both refuse registration of the lowest real-time signal, so on Linux a handler for it must get `registration_failed(SignalRegistrationRefused)` and dispose — including a second handler on the same signal, whose registration would hang if a failed install wedged the registration state.
- A full-program test for `wait = true`: the program exits only after the signal is delivered and the notify returns false, so the test goes red on either a wait regression or a dispose-chain regression.
- A full-program test for shutdown: an undisposed `wait = false` handler leaves its signal registered when the runtime exits, and the program's `_final` reads the disposition back to verify the operating system's default was restored — red if the shutdown restore regresses.
- CI runs on Linux, macOS, and Windows. The signals tests were previously excluded on Windows because the registration race that synchronous registration removes aborted the process; they now run there, so all three backends are verified on every change.

# Drawbacks

This is a breaking change. All existing code that creates a `SignalHandler` or calls `SignalRaise` will need to be updated to pass a `SignalAuth` parameter, and `SignalHandler` callers must also validate the signal number through `MakeHandleableSignal`. The auth migration is mechanical — add `SignalAuth(env.root)` at the point where signals are set up. The `HandleableSignal` requirement adds a match expression at the call site, but this is a one-time cost at the boundary where signal numbers enter the system.

This change breaks two more things. Because `dispose` now takes the auth, `SignalHandler` no longer satisfies `DisposableActor`, so a `bureaucracy.Custodian` can no longer dispose one directly; the replacement is disposing the handler where the auth is held, or a small adapter actor that captures the auth. And a class that conformed to `SignalNotify` only structurally — without declaring `is SignalNotify` — must add `registration_failed` or declare the interface, since default method bodies don't count toward structural subtyping.

# Alternatives

## Remove signals from stdlib entirely

The current signal abstraction is broken enough to warrant considering whether it should exist in the standard library at all. Signals are an inherently Unix concept with platform-specific edge cases. Users who need signal handling could use FFI to call the C signal APIs directly, giving them full control over the behavior.

The argument against removal is that signal handling is common enough that having a safe, capability-secured abstraction in the standard library is valuable. Without it, every user writes their own FFI bindings, likely reproducing the same platform inconsistencies that this RFC fixes.

## Keep current behavior and document it

We could keep the existing single-handler-per-signal behavior and simply document that registering multiple handlers is not supported. This avoids the breaking change but doesn't fix the platform inconsistency (first-wins vs last-wins) and doesn't add capability security. It would also mean the signals package remains the only I/O primitive without auth requirements.

# Unresolved questions

None at this time. The core design decisions — centralized dispatch, auth requirement, validated signal types, multiple subscribers with a fixed cap of 16, synchronous registration, failure reporting through `registration_failed`, undefined notification order, fatal signal prevention — have been discussed and agreed upon, and the prototype in [ponylang/ponyc#4984](https://github.com/ponylang/ponyc/pull/4984) implements them.

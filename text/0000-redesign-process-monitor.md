- Feature Name: redesign-process-monitor
- Start Date: 2026-07-22
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Redesign the standard library's `process` package to correctly detect child exit and close a number of bugs that are impossible to fix based on the current model.

# Motivation

The old monitor was built on one assumption: a child has exited once its stdout and stderr have both reached end-of-file. It sounds reasonable. It is wrong.

A pipe reaches end-of-file only when every process holding its write end has closed it. The child is not always the last one holding that write end. A child can spawn a grandchild, and the grandchild inherits the child's stdout and stderr. On the other side, the parent can still be holding the child's stdin open. As long as anything else holds a pipe open, it stays open after the child is gone. The end-of-file never arrives. So the monitor reported the child's exit late, or never reported it at all, while the program blocked waiting for a `ProcessNotify.dispose` callback that would not come and the child stayed a zombie.

That single wrong assumption caused two bugs.

The motivating case is [ponylang/ponyc#5764](https://github.com/ponylang/ponyc/issues/5764). The child exits cleanly, but a grandchild that inherited its stdout and stderr keeps running and holds the pipes open. One command reproduces it: `sh -c "some_daemon & exit 7"`. The pipes don't reach end-of-file until the grandchild exits, so `dispose` is delayed until then. If the grandchild is a daemon that outlives the parent, `dispose` never fires at all. Either way, the child stays a zombie in the meantime.

[ponylang/ponyc#5748](https://github.com/ponylang/ponyc/issues/5748) is the same fault from the other side. The exit status is never reported while the parent holds the child's stdin open. Same broken assumption, and the same change fixes it.

Two more bugs live in the same code, and this redesign closes them along the way. On POSIX, `dispose()` calls `kill()` on the child's pid, but by the time it runs, that pid may already have been reaped and recycled, so the signal can land on whatever unrelated process now holds the old number ([ponylang/ponyc#5765](https://github.com/ponylang/ponyc/issues/5765)). And the fork-error path leaks every pipe it had already opened ([ponylang/ponyc#5766](https://github.com/ponylang/ponyc/issues/5766)).

This is not theoretical. ponyup, Pony's toolchain installer, had tests that ran the process monitor, and they hung. Often. The monitor was undependable enough that those tests were eventually pulled out and replaced.

None of this is fixed in a released ponyc today. An earlier interim patch, [ponylang/ponyc#5763](https://github.com/ponylang/ponyc/pull/5763), was closed in favor of fixing it properly in this redesign, so [ponylang/ponyc#5748](https://github.com/ponylang/ponyc/issues/5748), [ponylang/ponyc#5764](https://github.com/ponylang/ponyc/issues/5764), and [ponylang/ponyc#5765](https://github.com/ponylang/ponyc/issues/5765) stay open until this lands.

The fix is to stop deriving the child's exit from its pipes and detect it directly, from an event the operating system raises when the child exits. Once the exit comes from a real event, the rest follows. Construction becomes a factory, so a `ProcessMonitor` only ever exists around a live child. The lifecycle collapses to three states. And the two loose bugs above close along with it.

# Detailed design

The design was worked out in [ponylang/ponyc#5769](https://github.com/ponylang/ponyc/discussions/5769), and the implementation is [ponylang/ponyc#5770](https://github.com/ponylang/ponyc/pull/5770). This section states the observable contract: the API, the guarantees, and what changes for callers. Where it would otherwise go into mechanism (the full state-transition table, the per-platform backend wiring, the reap sequence), the specifics live in that PR.

## What changes for callers

Today a caller constructs the monitor directly:

```pony
let pm = ProcessMonitor(sp_auth, bp_auth, consume notifier, path, args, vars)
```

After this change, the caller calls `StartProcess` and matches on the result:

```pony
match StartProcess(sp_auth, bp_auth, consume notifier, path, args, vars)
| let pm: ProcessMonitor => // a live child is running
| let err: ProcessError  => // never started; err says why
end
```

`StartProcess` is a primitive. Its `apply` does the work the constructor used to:

```pony
fun apply(
  auth: StartProcessAuth,
  backpressure_auth: ApplyReleaseBackpressureAuth,
  notifier: ProcessNotify iso,
  path: FilePath,
  args: Array[String] val,
  vars: Array[String] val,
  wdir: (FilePath | None) = None)
: (ProcessMonitor | ProcessError)
```

The old constructor's trailing `process_poll_interval: U64 = Nanos.from_millis(100)` parameter is gone. Nothing polls anymore.

A `ProcessError` return means no process was started. None of the notifier's callbacks will fire; there is no monitor and no child. Failures that used to arrive asynchronously through `ProcessNotify.failed` — no execute permission, a missing executable, and now a Linux kernel too old for `pidfd_open` — are returned synchronously by `StartProcess`, and no monitor is created for them.

## Construction as a factory

Actor constructors can't fail. The old `ProcessMonitor` constructor still had to do fallible setup: check the exec capability, check that the file exists, create the pipes, and fork. All of it ran inside the actor, and a constructor's only way to report a failure from inside itself was to hand it back asynchronously through `ProcessNotify.failed`.

The factory does all of that before the actor exists, plus a kernel-support probe (`pidfd_open` on our own pid, where `ENOSYS` means the kernel is too old). It creates the four pipes — stdin, stdout, stderr, and the `_err` startup-error relay — and forks and execs. If any of that fails, it closes whatever it had already opened and returns a `ProcessError`. Only on success does it build the actor, around a live child and its pipes.

That buys one guarantee: a `ProcessMonitor` only ever exists around a running child. There is no "failed to start" state for it to be in.

The failures that are genuinely asynchronous stay that way. An `execve` or `chdir` that fails in the forked child surfaces later through the `_err` relay pipe, and the running actor reports it through `ProcessNotify.failed`, exactly as before. What moved to the factory is the setup that can be checked before the child runs. What stayed asynchronous is what can only be determined after it starts.

## Exit detection: a native per-platform event

The child's exit is delivered as a native operating-system event, over the same asio machinery the pipes already use, not a poll. That event is the only signal that the child has exited.

A pipe reaching end-of-file now means one thing: stop reading that pipe. A read or write error on a pipe (POLLERR) closes only that pipe. A pipe-level problem no longer counts as a child exit, because it never was one.

The event has a different shape on each platform, one line each:

- **Linux:** a pidfd from `pidfd_open`, registered with epoll, that becomes readable when the child exits. It refers to the exact process, so it is immune to pid recycling. It needs Linux 5.3 or newer.
- **macOS, FreeBSD, DragonFly, OpenBSD:** a kqueue `EVFILT_PROC` filter with `NOTE_EXIT`. No version floor.
- **Windows:** a waitable process handle that signals on exit. No version floor.

When the event fires, the actor reaps the child (`waitpid`, the Windows handle wait, or `GetExitCodeProcess`) to collect the exit status and clear the zombie, then reports it.

## The three lifecycle states

Because the factory guarantees a live child before the actor is built, the actor has no "not started" state and no "failed to start" state. If a `ProcessMonitor` exists, a child is running. That collapses the lifecycle to three states. The full transition table is in the PR; here is what each state means to a client.

- **Running.** The child is alive and being monitored. Reads deliver stdout and stderr, writes queue to stdin under backpressure, `execve` and `chdir` errors surface through the `_err` pipe, and the exit event is armed.
- **Disposing.** The client called `dispose()`. The child has been killed and the pipes closed, and the monitor is waiting for the exit event to confirm it. This is a distinct state from Running for two reasons. The reap that follows must not deliver any more output, because the client cancelled, where a natural-exit reap does deliver the child's remaining output. And a second call to the `ProcessMonitor.dispose()` method in this state is a no-op rather than a redundant `kill()`.
- **Reaped.** The exit event fired and the status was collected (or a reap error occurred); the `ProcessNotify.dispose` or `failed` callback has been called; the state is absorbing and inert. The `ProcessMonitor.dispose()` method here is a no-op and never calls `kill()`.

## Error vocabulary

`ProcessError` is a `class val` carrying an `error_type: ProcessErrorType` and an optional human-readable `message`. The class already exists today; this RFC does not introduce it. What the RFC does is put that type on the factory's return, so a construction failure is data the caller matches on rather than a callback delivered later.

The vocabulary itself changes in two places.

`ExecveError` used to mean two different things. One was "the file doesn't exist," a precondition, checkable before the child ever runs. The other was "`execve` failed in the child," a genuinely asynchronous failure relayed back through the `_err` pipe. One error type for two unrelated conditions, told apart only by which channel delivered them. The redesign splits them. Missing-file becomes its own variant, `ExecutableNotFound`, returned synchronously by `StartProcess`. `ExecveError` is left to mean only the actual `execve` failure in the child.

A new variant, `UnsupportedKernel`, covers a kernel too old to report a child's exit: Linux older than 5.3, with no `pidfd_open`.

Where each error is delivered follows from when it can be determined. Returned synchronously by `StartProcess`: `CapError` (no exec capability), `ExecutableNotFound` (a missing or directory path), `UnsupportedKernel`, `PipeError`, and `ForkError`. Still arriving through `ProcessNotify.failed` while the child runs: `ExecveError`, `ChdirError`, `UnknownError` (the child's startup-failure relay), and `WriteError` (a failed write to the child's stdin), plus `WaitpidError`, which can arrive as a terminal error in place of `dispose` when the exit status can't be read.

The full union:

```pony
type ProcessErrorType is
  ( ExecveError
  | ExecutableNotFound
  | UnsupportedKernel
  | PipeError
  | ForkError
  | WaitpidError
  | WriteError
  | KillError
  | CapError
  | ChdirError
  | UnknownError
  )
```

## The guarantees

- **The `ProcessNotify.dispose` callback fires exactly once.** `dispose(status)` runs only on the single status-carrying transition into the absorbing Reaped state, and nothing leaves that state.
- **All of the child's own output is delivered before `dispose`.** When the exit event fires, the child's last writes may still be unread in the pipe buffer. A dead child can't still be writing, and everything it did write reached the buffer before it exited, so what remains is bounded, and it is drained before `dispose`. Two narrow cases are out of scope. With `expect(qty)` set, a final residual smaller than `qty` at end-of-file is not delivered; that is pre-existing behavior. And a child that grows its own pipe buffer past the drain cap and floods it just before exiting has the overflow truncated; that is a deliberate bound on teardown.
- **Backpressure that was applied is always released.** No teardown path abandons stdin without releasing the backpressure it applied.
- **`kill()` never targets a reaped pid** ([ponylang/ponyc#5765](https://github.com/ponylang/ponyc/issues/5765)). `kill()` is reachable only on the Running-to-Disposing transition, where the child is an unreaped zombie the monitor still owns, so its pid cannot have been recycled. On Linux the pidfd refers to the exact process regardless, and on Windows the wait is on a handle that never recycles.
- **No file-descriptor or asio-event leak** ([ponylang/ponyc#5766](https://github.com/ponylang/ponyc/issues/5766)). Every factory failure path closes both ends of every pipe it opened, every terminal path closes all four pipes, and asio events are torn down at close.

## Behavior changes

These are the divergences from released ponyc. "Today" means the released behavior; the numbered item is what this RFC changes it to.

1. **Construction.** The `ProcessMonitor(...)` constructor becomes the `StartProcess` factory, returning `(ProcessMonitor | ProcessError)`. Breaking.
2. **Construction failures are synchronous.** No exec capability, a missing file, a pipe or fork failure, or an unsupported kernel are returned synchronously by `StartProcess`. Today they arrive through `ProcessNotify.failed` on a monitor that wraps no real child.
3. **Error vocabulary.** `ExecutableNotFound` is added, splitting the missing-file case out of the overloaded `ExecveError`. `UnsupportedKernel` is added.
4. **Exit detection.** Today the exit is inferred from stdout and stderr both reaching end-of-file. Now a native per-platform exit event is the only exit signal.
5. **Descendant output after the child exits.** Today it is delivered in full, or the monitor hangs, which is [ponylang/ponyc#5764](https://github.com/ponylang/ponyc/issues/5764). Now it is cut off at the reap.
6. **Pipe error (POLLERR).** Today it tears the whole monitor down. Now it closes only that one pipe, and the child keeps being monitored to its actual exit.
7. **Platform floor.** Linux now needs kernel 5.3 or newer, for `pidfd_open`. On an older kernel, `StartProcess` returns `UnsupportedKernel`. There is no floor on macOS, the BSDs, or Windows.

The `ProcessNotify` interface is preserved. Its method set is unchanged: `created`, `stdout`, `stderr`, `failed`, `expect`, `dispose`. What changed is when those fire and the guarantees around them. `created` is always called first, because a monitor only exists around a running child. The `ProcessNotify.dispose` callback is called at most once, with the exit status. And `failed` can now be terminal, delivering a `WaitpidError` in place of `dispose` when the exit status can't be read.

# How We Teach This

The `process` package docstring leads with `StartProcess` and the match-on-result pattern, and documents the Linux kernel floor. The release notes for the ponyc version this ships in carry the breaking migration, with the before and after side by side.

The terminology a user needs is small: `StartProcess`, the factory used in place of a constructor; `ProcessMonitor`, which now always means a live child; and `ProcessError`, with `ExecutableNotFound` and `UnsupportedKernel` as its new variants.

# How We Test This

There is a trap in testing the main bug, and it shapes the whole approach. Asserting that `dispose(Exited(7))` fires is not a discriminating test for [ponylang/ponyc#5764](https://github.com/ponylang/ponyc/issues/5764). On the buggy code, once the grandchild finally releases the pipes, the same `Exited(7)` is reported, just late, or never. A status-only assertion passes on the bug. The only thing that separates correct from broken is time. So every test for [ponylang/ponyc#5764](https://github.com/ponylang/ponyc/issues/5764) and every stdin test has to be built on a categorical time separation (a grandchild that outlives the timeout, an unbounded self-terminating grandchild, a wide `elapsed` window), not a tuned latency threshold that a slow machine could trip on its own.

Two layers of tests cover the design.

Real-process tests cover the operating-system-level behavior: fd inheritance, a grandchild holding the pipes open. A silent grandchild (`sh -c "sleep 30 & exit 7"`, with a timeout well under the grandchild's lifetime) pins the exit-detection fix. The grandchild case is also asserted to still deliver the child's own buffered output; a flooding grandchild is asserted not to stall teardown; a child that closes its output and blocks on stdin completes only after a delayed `done_writing()`; a dispose-exactly-once test runs against a reap race; and a coarse fd-leak stress loop.

The state-machine guarantees are verifiable without a real operating-system process. Because the factory hands the actor its child as a value, a test can substitute a stand-in child in its place, which makes a PonyCheck property possible: it generates random orderings of the client-facing events (`write`, `done_writing`, `dispose`, and "the child exits now") and asserts that the guarantees hold for every ordering. `dispose` fires exactly once, `kill()` never runs after a reap ([ponylang/ponyc#5765](https://github.com/ponylang/ponyc/issues/5765)), and applied backpressure is always released.

The precondition failures (no capability, a missing file, an unsupported kernel) are now synchronous, so they are asserted directly on the `StartProcess` return, with no notifier round-trip.

Several existing tests stay green, each one pinning a contract clause: the exec/chdir failure path fires both `failed` and `dispose`; `dispose` never fires when construction fails (now asserted against the factory's error return instead of a callback); a kill while the child is running yields `Signaled`; and the existing stdin, stdout, ordering, `expect`, and [ponylang/ponyc#5748](https://github.com/ponylang/ponyc/issues/5748) tests.

CI runs on Linux, macOS, and Windows, which is where the three exit backends are exercised.

# Drawbacks

It is a breaking change, shipped as a single cutover with no compatibility shim. Every caller of the `ProcessMonitor` constructor has to move to `StartProcess` and handle the `ProcessError` arm of the result, and a caller's code will not compile until it does.

A descendant that outlives the child loses its post-exit output. Once the child exits, the reap cuts the pipes, and anything a grandchild writes after that point is dropped. This is a real loss, and it is accepted on purpose. It falls straight out of the decision to monitor the child instead of its descendants, and monitoring the descendants, waiting for their end-of-file, is exactly the hang in [ponylang/ponyc#5764](https://github.com/ponylang/ponyc/issues/5764). There is no design that both fixes the bug and keeps delivering a descendant's output; the two are the same behavior. If a real use case for the descendant's output surfaces, we revisit it then.

On Linux older than 5.3, you can no longer start a monitored process. Without `pidfd_open` there is no exit event to wait on, so `StartProcess` returns `UnsupportedKernel` instead of a monitor.

And there is more to maintain: a native exit backend on every operating system (pidfd on Linux, kqueue `EVFILT_PROC` on the BSDs and macOS, a waitable handle on Windows).

# Alternatives

The thing that disqualifies most of the alternatives is one property: they leave a path where the monitor hangs. That is not a hypothetical cost. We hit it in ponyup (see Motivation). Any design that keeps a hang path is off the table, with one exception, noted below, that is rejected for a different reason.

**Keep inferring the exit from stdout/stderr end-of-file (the status quo).** This is the bug. It hangs and it leaves zombies ([ponylang/ponyc#5764](https://github.com/ponylang/ponyc/issues/5764), [ponylang/ponyc#5748](https://github.com/ponylang/ponyc/issues/5748)). Doing nothing keeps all of that.

**Follow the descendants to their real end-of-file, to keep delivering their output.** This is [ponylang/ponyc#5764](https://github.com/ponylang/ponyc/issues/5764)'s hang, by design. A daemon grandchild never releases the pipes, so the monitor waits on an end-of-file that never comes. Forever.

**Patch the pipe logic in place.** [ponylang/ponyc#5763](https://github.com/ponylang/ponyc/pull/5763) was an interim patch for [ponylang/ponyc#5748](https://github.com/ponylang/ponyc/issues/5748), the parent-holds-stdin case; it was closed in favor of this redesign. A targeted patch fixes one hang path and leaves the grandchild one standing. Still hangs.

**Poll `waitpid` on a timer.** This one actually works. Polling `waitpid` detects the child's exit directly, so it does not hang. It is rejected on cost. It needs a per-child `Timers` actor that allocates eagerly, and it is a half-measure: the native-event design is where this is going to end up, so shipping an interim polling release buys nothing but a version to migrate off of later.

**A trait-based state-object machine for the lifecycle,** instead of the three flat states. Rejected because the pieces those state objects would have to share (the pipes, the read buffer, the pending-write list) are per-actor and live across both the Running state and the reap. Splitting the states into separate objects would not clean that up; it would just add indirection over the same shared state.

The cost of not doing any of this is the status quo: the monitor stays undependable, and programs built on it keep hanging.

# Unresolved questions

The names that discussion [ponylang/ponyc#5769](https://github.com/ponylang/ponyc/discussions/5769) called provisional (`StartProcess`, the state names, the unsupported-kernel error) are settled in the implementation and are the ones used here.

The descendant-output truncation is accepted, to be revisited only if a real use case for a descendant's post-exit output surfaces.

Otherwise, none.

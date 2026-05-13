- Feature Name: socket-runtime-three-state-result
- Start Date: 2026-04-30
- RFC PR:
- Pony Issue:

# Summary

Change the five `PONY_API` socket runtime functions (`pony_os_writev`, `pony_os_send`, `pony_os_recv`, `pony_os_sendto`, `pony_os_recvfrom`) to return a three-state result enum (`PONY_SOCKET_OK`, `PONY_SOCKET_RETRY`, `PONY_SOCKET_ERROR`). The operation's byte count moves to a new `size_t* count_out` out-parameter. The C-level return type is `uint8_t`, matching the Pony FFI declaration. This is a breaking C API change.

# Motivation

The current shape of these five functions is muddled. Each one returns a `size_t` that has to encode three things at once: how many bytes moved, whether the operation would block, and whether it failed outright. Three distinct outcomes squeezed into one value channel.

The original encoding used the Pony partial-function mechanism. The function returned a byte count on success and called `pony_error` on failure, which the caller surfaced through `?`. Would-block was reported as a zero-byte success. That worked, in the sense that all three outcomes were distinguishable. It also wired socket I/O into the C++ exception unwind path. PR [ponylang/ponyc#5002](https://github.com/ponylang/ponyc/pull/5002) is removing that unwind path runtime-wide, so this code has to move with it.

PR #5002, in its current draft, takes the simpler step. Drop `pony_error`, return `SIZE_MAX` to signal failure. This works mechanically but the result is uglier than what came before. Three cases now compete in the same `size_t` channel:

```
0           would-block (try again later)
N (1..)     N bytes moved
SIZE_MAX    error
```

A "byte count" that can also mean "no progress" or "the call failed" is not a byte count. Every caller has to reason about three sentinels in one return value. Adding `SIZE_MAX` to the existing zero-as-would-block convention makes the overload worse, not better.

The right move is to split the status from the data. A small status enum says what happened. An out-parameter carries the byte count. Each channel means one thing.

There's a second motivation for the three-state shape specifically. Once you've committed to splitting status from byte count, you might think a boolean is enough. Succeeded or failed. It isn't. The "would-block" case has different caller semantics than a real error. The caller should retry on a backpressure signal but should give up on a connection failure. Collapsing them into a single `false` loses that distinction. Representing would-block as `true` with `count == 0` reintroduces the same overload we just removed. Three states fall out of the problem.

# Detailed design

A working implementation of this RFC is at [ponylang/ponyc@99bc8324](https://github.com/ponylang/ponyc/commit/99bc8324). It sits on top of [ponylang/ponyc#5002](https://github.com/ponylang/ponyc/pull/5002) (the broader work to remove `pony_error`).

## Wire contract

The wire contract for the result enum is fixed. Downstream consumers in any binding language must use these exact values:

```
0 = OK     (operation completed)
1 = RETRY  (transient condition, try again)
2 = ERROR  (unrecoverable failure)
```

## C side

A new typedef in `src/libponyrt/lang/socket.h`:

```c
typedef uint8_t pony_socket_result_t;
#define PONY_SOCKET_OK    ((pony_socket_result_t)0)
#define PONY_SOCKET_RETRY ((pony_socket_result_t)1)
#define PONY_SOCKET_ERROR ((pony_socket_result_t)2)
```

The type is `uint8_t` rather than a C `enum` because the Pony FFI declares the return as `[U8]`. A C `enum` is implementation-defined width (typically 4 bytes on common platforms). Having the C side return a 4-byte value while the Pony side reads 1 byte happens to work on x86-64 SysV by coincidence. The canonical enum value fits in the low byte. It's not contract-guaranteed across platforms, ABIs, or compiler flags. Pinning the type at one byte avoids the whole class of "works on Linux, breaks on something else" failures.

Each of the five functions takes a trailing `size_t* count_out`:

```c
PONY_API pony_socket_result_t pony_os_writev(asio_event_t* ev, ..., size_t* count_out);
PONY_API pony_socket_result_t pony_os_send(asio_event_t* ev, const char* buf, size_t len, size_t* count_out);
PONY_API pony_socket_result_t pony_os_recv(asio_event_t* ev, char* buf, size_t len, size_t* count_out);
PONY_API pony_socket_result_t pony_os_sendto(int fd, const char* buf, size_t len, ipaddress_t* ipaddr, size_t* count_out);
PONY_API pony_socket_result_t pony_os_recvfrom(asio_event_t* ev, char* buf, size_t len, ipaddress_t* ipaddr, size_t* count_out);
```

The contract: `*count_out` is **always** written, regardless of return value. `OK` writes the byte count. `RETRY` and `ERROR` write `0`. Callers must pass a non-NULL pointer. Passing NULL is undefined and will segfault.

## State semantics

Most call sites follow a regular pattern. On POSIX, all five functions behave the same way:

- success returns `OK` with the byte count
- `EWOULDBLOCK`/`EAGAIN` returns `RETRY` with 0
- any other errno returns `ERROR` with 0

`pony_os_recv` and `pony_os_recvfrom` add one POSIX-specific case: `recv`/`recvfrom` returning 0 (peer closed) maps to `ERROR`.

Windows departs from POSIX in two specific ways. Read-side IOCP paths (`recv`, `sendto`, `recvfrom`) cannot signal `RETRY` because the underlying IOCP API doesn't surface a would-block analog at this layer; they either queue the operation (`OK`) or fail (`ERROR`). Write-side IOCP paths (`writev`, `send`) report a backpressure-relevant count rather than literal bytes when the I/O is pending.

The full table:

| Function | Platform | Condition | State | `*count_out` |
|---|---|---|---|---|
| writev/send | POSIX | data sent | `OK` | N (bytes) |
| writev/send | POSIX | `EWOULDBLOCK`/`EAGAIN` | `RETRY` | 0 |
| writev/send | POSIX | other errno | `ERROR` | 0 |
| writev | Windows | immediate or `WSA_IO_PENDING` | `OK` | wsacnt (buffer count, not bytes) |
| send | Windows | immediate | `OK` | bytes accepted |
| send | Windows | `WSA_IO_PENDING` | `OK` | input `len` |
| writev/send | Windows | `WSAEWOULDBLOCK` | `RETRY` | 0 |
| writev/send | Windows | other error | `ERROR` | 0 |
| recv | POSIX | `received > 0` | `OK` | N (bytes) |
| recv | POSIX | `EWOULDBLOCK`/`EAGAIN` | `RETRY` | 0 |
| recv | POSIX | other errno OR `received == 0` (peer closed) | `ERROR` | 0 |
| recv | Windows | `iocp_recv` queued the read | `OK` | 0 (count arrives async) |
| recv | Windows | `iocp_recv` failed | `ERROR` | 0 |
| sendto | POSIX | invalid address | `ERROR` | 0 |
| sendto | POSIX | data sent | `OK` | N (bytes) |
| sendto | POSIX | `EWOULDBLOCK`/`EAGAIN` | `RETRY` | 0 |
| sendto | POSIX | other errno | `ERROR` | 0 |
| sendto | Windows | `iocp_sendto` queued | `OK` | 0 |
| sendto | Windows | `iocp_sendto` failed | `ERROR` | 0 |
| recvfrom | POSIX | `recvd > 0` | `OK` | N (bytes) |
| recvfrom | POSIX | `EWOULDBLOCK`/`EAGAIN` | `RETRY` | 0 |
| recvfrom | POSIX | other errno OR `recvd == 0` (peer closed) | `ERROR` | 0 |
| recvfrom | Windows | `iocp_recvfrom` queued | `OK` | 0 |
| recvfrom | Windows | `iocp_recvfrom` failed | `ERROR` | 0 |

A few rows want explicit explanation.

**Windows IOCP `recv`/`sendto`/`recvfrom` return `OK` with `count = 0`.** On Windows, `recv`, `sendto`, and `recvfrom` are queued through I/O Completion Ports. The actual byte count arrives asynchronously through the ASIO event mechanism. The synchronous return is just "the operation has been started." Successfully starting is `OK`, and there's no count yet to report.

**Windows IOCP `writev`/`send` return `OK` with the input buffer count or input length.** This is preserved from existing behavior. The Pony stdlib uses this value as a backpressure-accounting signal, not as a literal byte count. On `WSA_IO_PENDING`, `pony_os_writev` returns the input `wsacnt` and `pony_os_send` returns the input `len`. The actual bytes-completed comes later via the IOCP completion event. Carrying `wsacnt` through `count_out` is mildly misleading. It's a buffer count, not bytes. Changing it would alter `_pending_sent` accounting in `tcp_connection.pony` and is preserved here as out of scope. No follow-up issue is filed; the behavior is intentional pre-existing accounting.

**`RETRY` shape across platforms.** All five POSIX paths can return `RETRY` (errno EWOULDBLOCK/EAGAIN). Windows `writev`/`send` can return `RETRY` (WSAEWOULDBLOCK). Windows `recv`/`sendto`/`recvfrom` cannot. IOCP doesn't surface a would-block analog at this layer. It either queues the operation or fails. Callers must still handle `RETRY` exhaustively for the future-proofing benefit of `match \exhaustive\`, but on Windows IOCP read and datagram paths, that arm is unreachable today. Pony's convention for guaranteed-impossible paths is `_Unreachable()` (a panic primitive), which makes the assumption explicit at runtime.

**Peer-closed (POSIX `recv`/`recvfrom` returning 0) maps to `ERROR`.** Today's stdlib treats peer-closed as a partial-function error and tears the socket down. The call sites don't distinguish errno failure from peer-closed; both go through the same close path. Keeping them collapsed in the new design preserves all existing call-site behavior. If a future consumer needs to distinguish them, that's a fourth state, and the design accommodates the addition cleanly.

There's a separate latent issue here for UDP. Per RFC 768, UDP datagrams of zero length are valid, so mapping `recvfrom == 0` to `ERROR` is wrong for UDP specifically. That's pre-existing behavior, not introduced by this RFC, and is tracked as [ponylang/ponyc#5289](https://github.com/ponylang/ponyc/issues/5289) for follow-up.

## Pony stdlib side

Pony's `match \exhaustive\` operates on union types, not raw integers. The U8 returned from the FFI has to be mapped into a closed union before it can be matched exhaustively. That's the "decoder" pattern below.

A new package-private file at `packages/net/_socket_result.pony` defines a Pony-side counterpart to the C-level result:

```pony
primitive _SocketResultOk
  fun apply(): U8 => 0

primitive _SocketResultRetry
  fun apply(): U8 => 1

primitive _SocketResultError
  fun apply(): U8 => 2

type _SocketResult is
  (_SocketResultOk | _SocketResultRetry | _SocketResultError)

primitive _SocketResultDecoder
  fun apply(v: U8): _SocketResult =>
    match v
    | _SocketResultOk() => _SocketResultOk
    | _SocketResultRetry() => _SocketResultRetry
    else _SocketResultError
    end
```

The integer wire values must match the C-side `PONY_SOCKET_*` constants. Both files cross-reference each other in comments. The decoder collapses any unknown U8 value to `_SocketResultError` so a future C-side variant addition that ships before the Pony decoder is updated fails closed. A unit test sweeps all 256 U8 values to verify the mapping is correct.

Call sites bind the decoded result to a local first, then `match \exhaustive\` on it. Inside a TCP connection actor:

```pony
var count: USize = 0
let result = _SocketResultDecoder(
  @pony_os_recv(_event, buf.cpointer(), buf.size(), addressof count))
match \exhaustive\ result
| _SocketResultOk => // count holds bytes received
| _SocketResultRetry => // mark unreadable, resubscribe
| _SocketResultError => error
end
```

The `\exhaustive\` annotation makes adding a future state on the C side a compile error at every call site, rather than a silent fall-through.

The Pony types are package-private (`_` prefix). Any downstream FFI consumer of these runtime functions writes their own counterpart of the result type and decoder. The wire contract (that `0`/`1`/`2` correspond to OK/Retry/Error) is documented in `socket.h` so a downstream consumer reading the header has what they need.

## Migration

A downstream Pony FFI consumer makes four changes:

1. Update the `use @...` FFI declaration: drop the `?`, change the return type to `[U8]`, add the trailing `count_out: Pointer[USize]`.
2. Define a result-type counterpart (three primitives, a union, and a decoder) once per package.
3. Replace each `try`/`?`/`else` call site with `var count: USize = 0` followed by a `match \exhaustive\` on the decoded result.
4. Verify each migrated call path runs.

Migration changes both the FFI declaration AND the surrounding control flow. It's not a mechanical type-only swap.

Existing declarations may differ from the stdlib's in argument naming or wrapping. The operative changes are the three above. Apply them to whatever shape your code is in.

The example below shows `pony_os_recv`. The same pattern applies to `pony_os_writev`, `pony_os_send`, `pony_os_sendto`, and `pony_os_recvfrom`. Only the FFI argument lists differ.

Before:
```pony
use @pony_os_recv[USize](event: AsioEventID, buffer: Pointer[U8] tag,
  size: USize) ?

try
  let len = @pony_os_recv(event, buffer, size)?
  if len == 0 then
    // would-block path
  else
    // len bytes were received
  end
else
  // pony_error() fired in the C runtime
end
```

After:
```pony
use @pony_os_recv[U8](event: AsioEventID, buffer: Pointer[U8] tag,
  size: USize, count_out: Pointer[USize])

// Define the counterpart once, at package scope:
primitive MyOk    fun apply(): U8 => 0
primitive MyRetry fun apply(): U8 => 1
primitive MyError fun apply(): U8 => 2

type MyResult is (MyOk | MyRetry | MyError)

primitive MyResultDecoder
  fun apply(v: U8): MyResult =>
    match v
    | MyOk()    => MyOk
    | MyRetry() => MyRetry
    else MyError
    end

// At each call site:
var count: USize = 0
let result = MyResultDecoder(
  @pony_os_recv(event, buffer, size, addressof count))
match \exhaustive\ result
| MyOk    => // count holds bytes received
| MyRetry => // would-block, try again later
| MyError => // unrecoverable error
end
```

A consumer wrapping the runtime in another binding language has more work. The function signature changed shape, not just types. A previously-correct binding declaring `size_t pony_os_recv(...)` will still link against the new `pony_socket_result_t pony_os_recv(..., size_t*)` because the underlying symbol is the same. Invoking it without the new out-param will write through whatever happens to be at the missing argument's stack slot. Verification means reading the new `socket.h` and confirming your declarations match the updated signatures byte-for-byte. The linker won't catch a mismatch, and Pony's dynamic FFI won't either.

# How We Teach This

The release notes for the ponyc version that ships this change include the migration steps shown above. The package-private Pony counterpart in `packages/net/_socket_result.pony` is the reference implementation. Downstream consumers can copy the shape with renamed primitives.

The wire contract (the integer values for OK/Retry/Error) is documented in `src/libponyrt/lang/socket.h` alongside the typedef and the `count_out` non-NULL contract.

There's no change to how Pony itself is taught. These are runtime FFI signatures, not language features.

# How We Test This

The new `_SocketResultDecoder` has a direct unit test in `packages/net/_test.pony` that sweeps all 256 U8 values, asserting that `0` decodes to `_SocketResultOk`, `1` to `_SocketResultRetry`, and everything else to `_SocketResultError`. The test also anchors the wire contract by asserting `_SocketResultOk()`, `_SocketResultRetry()`, and `_SocketResultError()` return the expected `0`/`1`/`2`.

The eight call sites in `tcp_connection.pony` and `udp_socket.pony` are exercised by the existing TCP and UDP integration tests in the same `_test.pony` file. Those tests cover the OK and Error paths for normal operation. The Retry paths get hit by the existing throttle tests on POSIX TCP writev. Three Retry paths have no integration coverage today: UDP `_write` EWOULDBLOCK silent-drop (tracked as [ponylang/ponyc#5288](https://github.com/ponylang/ponyc/issues/5288)) and the unreachable Windows IOCP Retry arms on `recv`, `sendto`, and `recvfrom` (the C side never produces them on Windows).

The Windows IOCP code paths run only on Windows CI. Local Linux test runs do not exercise them. The Windows CI job must pass before merging. Beyond that, ponyc's standard CI coverage is sufficient.

# Drawbacks

This is a breaking C API change for any FFI consumer of the five socket runtime functions. Both the function signature and the ABI shape change. Return type goes from `size_t` to `uint8_t`. The parameter list grows by one trailing pointer. Pony's dynamic FFI will not catch a stale `use @...` declaration. The call will silently invoke the new C with the old signature shape and corrupt stack or write to garbage memory.

Downstream consumers that haven't migrated will fail at the first call to one of these functions, not at compile time. CI for those projects only catches the issue if the relevant code path actually runs.

Consumers must also write their own Pony-side counterpart of the result type. The package-private choice for `_SocketResult` is deliberate. The type is small, copying the shape into another package is cheap, and forcing a stable public type would commit ponyc to API guarantees we don't need to make. It does mean every consumer carries roughly fifteen lines of repetitive declaration.

A deprecation cycle was considered and rejected. PR #5002 is removing the runtime-wide C++ exception unwind path that today's `pony_error`-based shape depends on. Anyone consuming these functions has to recompile against new ponyc regardless. Splitting the migration into a deprecation phase doubles the work without giving consumers a stable old version they could keep using. The clean break ships once.

There's a small runtime cost. The old shape returned the byte count in a register. The new shape writes it through a caller-supplied pointer. On a hot syscall path that adds roughly one stack store and one reload per call. That's invisible against the cost of the syscall itself, which is on the order of a microsecond. No measured regression is expected.

# Alternatives

**Boolean status with the would-block case represented as `count == 0`.** This was the first design considered. Simpler than three states. It fails on `recv`. Today's POSIX `recv` returning 0 means the peer closed (an error condition), and the would-block case also produces a `count == 0` reading. With a boolean `true`/`false`, both peer-closed and would-block surface as `true` with `count == 0`, and the caller can't distinguish "the connection is dead" from "no data right now, try again." Reintroducing a sentinel for would-block (e.g., `count == SIZE_MAX` means would-block) puts us right back where we started.

**Boolean status with a separate `would_block` out-parameter.** Same effect as three states but with three out-channels (status bool, count, would-block bool) instead of two. More awkward at every call site, no benefit.

**Tuple return: `(pony_socket_result_t, size_t)`.** Pony FFI supports tuple returns. Stdlib uses them in places (e.g., `packages/builtin/signed.pony` declares `[(I32, Bool)]` for LLVM intrinsics). This would let call sites avoid the `var count: USize = 0` and `addressof count` ceremony. Rejected because the C ABI for returning a struct of `(uint8_t, size_t)` varies across platforms. System V x86-64 returns small structs in registers, Windows x64 has different rules, 32-bit platforms have their own conventions. Picking out-param keeps the C ABI uniform and predictable. Tuple return is also a Pony-FFI-only convenience. Downstream consumers in non-Pony bindings would still need to deal with the underlying C calling convention.

**Single status enum with more states (e.g., distinguishing `CLOSED` from `ERROR`, or separating `EWOULDBLOCK` from `EAGAIN`).** Rejected because no current consumer needs the extra distinctions. The stdlib's TCP and UDP code paths treat errno failure and peer-closed identically. A fourth state can be added later if a consumer demonstrates the need. The union shape and `match \exhaustive\` make the addition tractable.

**Leave the SIZE_MAX-sentinel scheme from PR #5002.** Briefly considered. Ship #5002 with the sentinel, accept the byte-count overload, save the breaking-change story for later. Rejected because the API is uglier, the overload makes the call sites harder to read, and the breaking change is happening anyway when the existing partial-function form goes away. Doing it cleanly in one cycle beats introducing a wart and then breaking the API again later to fix it.

**Keep using `pony_error` for failure.** What the existing code does, and what PR #5002 is moving away from. The broader story for #5002 is "remove the C++ exception infrastructure from runtime error reporting." Keeping `pony_error` here would defeat the point.

# Unresolved questions

None.

- Feature Name: TCPConnectionNotify Received Times
- Start Date: 2017-03-19
- RFC PR: https://github.com/ponylang/rfcs/pull/85
- Pony Issue: https://github.com/ponylang/ponyc/issues/1773

# Summary

Update `TCPConnectionNotify.received` to take an additional parameters that indicates the number of times during this scheduler run that received has been called.

# Motivation

On non-Windows platforms, TCPConnection will read data off of a socket until:

- there's no more data to read
- a max size is hit
- `TCPConnectionNotify.received` returns false

The last option was introduced via [RFC #19](https://github.com/ponylang/rfcs/blob/main/text/0019-tcp-received-bool.md) to give the programmer more control of when to yield the scheduler. This was a noble goal but is weakly implemented. In order to exercise better control, the programmer needs an additional bit of information: the number of times during *this scheduler run* that `received` has been called.

As we began to use RFC #19 at Sendence it became clear that is wasn't doing what we wanted. What we hoped to be able to do was read up to X number of messages off the socket, inject them into our application and then give up the scheduler.

Our initial implementation was to keep a counter of messages received in our `TCPConnectionNotify` instances and when it hit a number such as 25 or 50, return false to give up the scheduler. This, however, didn't accomplish what we wanted. The following scenario was possible:

Scheduler run results in 24 calls to `received`. When the next scheduler run would occur, we'd get 1 more `received` call and return false. What we really wanted was to *read no more than 25 messages per scheduler run*.

In order to accomplish this, we added an additional parameter to `TCPConnectionNotify.received`: the number of times during this scheduler run that `received` has been called (inclusive of the existing call). This gives much more fine-grained control over when to "prematurely" give up the scheduler and play nice with other sockets in the system.

You might think, "why not lower the max read size"? And this certainly is something you could do, but lowering the max read size, lowers how large of a chunk we read from the socket during a given system call. In the case of a high-throughput system, that will greatly increase the number of system calls thereby lowering performance.

# Detailed design

Change interface of `TCPConnectionNotify.received` from

`  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool`

to

`fun ref received(conn: TCPConnection ref, data: Array[U8] iso,
    times: USize): Bool`

Update `TCPConnection._pending_reads` to keep track of the number of times that we call `received` on the notify and pass along accordingly.

Update `TCPConnection._complete_reads` to pass a `1` for times value as it is never called in a loop.

# How We Teach This

- Update method documentation on TCPConnectionNotify to indicate what `times` is used for.
- Update `TCPConnection` actor documentation to include a example usage of `times`.

Note, this functionality is very useful when used with `expect` but without, is like the preceeding RFC, probably mostly useless. As such, example usage code should use `expect`.

There are also a couple of examples that need to be updated:

- echo
- net/client
- net/server

# How We Test This

We don't currently have any tests to verify this interaction when run "in the wild".

# Drawbacks

Breaks the existing API

# Alternatives

- Leave as is without addressing issue.
- Redesign `TCPConnection` from scratch to provide another way to better share the scheduler while keeping system call overhead low

# Unresolved questions

This has been in use at Sendence for couple months now. We have no unresolved questions.

- Feature Name: Unix Domain Socket Support
- Start Date: 2021-11-22
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

The intent is to extend to runtime library, together with the `net` package, to
add support for Unix domain sockets. That is, currently there is support for TCP
and UDP sockets, but not for Unix domain sockets.

# Motivation

Unix domain sockets, and in particular, named Unix domain sockets can provide
interprocess communications support that is well suited to modular component
development under Unix. Additionally, integration with existing services
sometimes requires interaction via named unix domain sockets.

Part of the motivation for supporting Unix domain sockets is the support for
connection oriented boundary preserving reads and writes. That is, the
`SOCK_SEQPACKET` type, under the `AF_UNXI` domain, provides reliable and
sequential datagram style sockets. This is useful for implementing system
services.

# Detailed design

We will provide implementations of:

- `UnixConnection`
- `UnixConnectionNotify`
- `UnixListener`
- `UnixListenerNotify`

When creating a new connection the socket type can be set to one of:

- `SOCK_STREAM`
- `SOCK_DGRAM`
- `SOCK_SEQPACKET`

When creating a new listener the socket type can be set to one of:

- `SOCK_STREAM`
- `SOCK_SEQPACKET`

Beyond the above coarse grained API types, it is expected that the actual
methods that are exposed will be similar to those of the TCP or UDP
implementations.

TODO/WIP - this section does not contains enough detail yet.

# How We Teach This

As with TCP and UDP sockets, the in-code documentation would provide sufficient
examples of the usage.

Most of the API patterns, in terms of notifiers etc., will be common to the Unix
domain sockets and the other supported socket types.

# How We Test This

It will be possible to implement unit tests to create unix domain sockets and
then exercise both the server side listening code and the client side connection
code.

Additionally, the build pipelines will be able to test this on all of the
supported Unix operating systems.

While the final implementation may benefit from reusing some o the existing TCP
or UDP code, the impact should be mitigated by existing testing.

# Drawbacks

## OS Specific

By definition, the Unix domain sockets are specific to particular supported
operating systems.

However, this would not impact TCP or UDP, and the programmer would be aware of
using OS specific features. On other OSes a suitable error can be returned.

# Alternatives

TODO/WIP - more alternatives probably need to be considered.

## Direct use of ASIO

It might be possible to implement the mechanism needed to unix domain sockets by
using the asio API directly. That way, `libponyrt` might not need to be changed.
Instead, calls from Pony code to `libc` could potentially be used, along with
making use of `_event_notify`.

For prior-art and an example of direct calls to ASIO, see the experimental
project:
[Lori](https://github.com/seantallen-org/lori/blob/main/lori/pony_asio.pony).

# Unresolved questions

## Naming

Should the new components be named: `UnixConnection`, `UnixListener` etc.? Or,
should the components be named: `UNIXConnection`, `UNIXListener` etc.?

## Abstract Socket Addresses

Should there be explicit support for the Linux specific abstract socket
addresses? Or, do we simply allow names to start with `\0` in order to enable
the abstract naming convention?

## Sharing interface definitions

Given the similarities between the TCP domain and the Unix domain (when using
the stream or sequential-packet socket types), or between the UDP domain and the
Unix domain (when using the datagram or sequential-packet socket types), should
there be an attempt to pull out common interface types?

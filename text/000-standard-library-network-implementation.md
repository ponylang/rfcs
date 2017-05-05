- Feature Name: Standard library network implementation
- Start Date: 2016-06-01
- RFC PR:
- Pony Issue:

# Summary

The standard library should include support for common network protocols and follow an established set of implementation guidelines. There needs to be a principle of clean layer separation and the codebase organization should reflect this.


# Motivation

The current codebase is somewhat disorganized and lacks a clean layer separation.

For example, the HTTP server codebase is closely coupled with both the TCP and SSL transport layer. The HTTP communication channel needs to separated from the HTTP message layer. And further, in the interest of supporting protocols such as WebSocket and HTTP/2, abstractions need to be devised such that a clean layer separation is possible.


# Detailed design

The principle of clean layer separation means that we generally need to devise abstractions for each layer that define a minimal interface needed to support a higher layer.

For example, the HTTP communication channel requires a socket interface that supports protocol details such as [PROXY PROTOCOL](http://www.haproxy.org/download/1.5/doc/proxy-protocol.txt) and [ALPN](https://tools.ietf.org/html/rfc7301). However, the implementation should not depend on either TCP or TLS.

Similarly, an HTTP message does not need to know if the communication happens over HTTP 1.0, 1.1 or 2.

It is suggested that each protocol implementation should be placed into a subdirectory of "packages/net", e.g. "packages/net/ip", that principal actors and classes carry the name of the protocol, e.g. "class SSLSocket", and that filenames do not carry the name of the protocol, e.g. "packages/net/ssl/socket.pony".

The relevant authentication primitives should be placed in a file "auth.pony" inside each protocol subdirectory.

It is outside the scope of this RFC to discuss concrete implementation details.


# How We Teach This

The acceptance of this RFC and subsequent implementation changes will require some minor changes to examples and packages outside the standard library.


# Drawbacks

Existing code will break.


# Alternatives

None are proposed at this time.


# Unresolved questions

None at this time.

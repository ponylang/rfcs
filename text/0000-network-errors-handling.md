- Feature Name: network errors handling
- Start Date: 2017-02-15
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Provide API for handling network errors.

# Motivation

Current interfaces, such as `TCPListenNotify`, `TCPConnectionNotify`
and `UDPNotify` do not provide any information about why some action
has failed. This makes it difficult to figure out software
configuration errors.  Knowledge about nature of network failure is
essential for production software.

# Detailed design

1. Create a primivite union of possible network errors, similar to
   `FileErrNo`, that maps a platform specific errno codes on these
   primitive values.

```pony
   type SocketErrNo is
     ( SocketOK
     | SocketError
     | SocketInUse
     | SocketConnRefused
     | SocketNetUnreach
     | SocketTimeout
     )
```

   Where:

* `SocketOK` - success
* `SocketInUse` - local address is already in use
* `SocketConnRefused` - no-one listening on the remote address
* `SocketNetUnreach` - no routing to remote host
* `SocketTimeout` - timeout while attempting connection
* `SocketError` - other socket error not listed above

2. Add private `_errno` field of `SocketErrNo` type into
   `TCPConnection`, `UDPSocket` and `TCPListener`.  On connection
   outcome, either success or failure, `_errno` must be set using
   corresponding OS errno code fetched using `SO_ERROR` socket option

3. Create publically available method `errno` which returns `_errno`,
   for example:

```pony
  fun errno(): SocketErrNo =>
    """
    Returns the last error code set for this socket
    """
    _errno
```

# How We Teach This

Update the doc strings for `TCPConnectionNotify.connect_failed`,
`UDPNotify.not_listening` and `TCPListenNotify.not_listening`
describing error fetching mechanism described in Design section.

Code example, showing usage of handling errors, is highly encouraged.

# How We Test This

Add test case of making invalid connection, checking that errno is set
uppon call to notifier.

# Drawbacks

Requires changes in `libponyrt/lang/socket.c` since actual value for
`SO_ERROR` is not exposed to pony level.

# Alternatives

Extend notifiers API, so error code is provided uppon call to
notifier.  This approach looks not that smooth to integrate as
proposed in Design section.

# Unresolved questions

How proposed API conforms with [RFC 23](https://github.com/ponylang/rfcs/blob/master/text/0023-network-dont-provide-default-implementation-for-failures.md)

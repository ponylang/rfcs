- Feature Name: ssl-alpn
- Start Date: 2018-05-28
- RFC PR:
- Pony Issue:

# Summary
Add server and client support for the Application-Layer Protocol Negotiation (ALPN) TLS extension to the `net/ssl` package.

# Motivation
Right now, for anybody who wants/needs to use the ALPN extension, there is no way around reimplementing or modifying the existing `net/ssl` package.
This is a particularly nasty limitation, since pony seems to be at least somewhat affine for web technologies (going from the `HTTPServer` that is/was part of the distributed packages).

And yet, without support for ALPN, there can be no viable http/2 server implementation using the
standard packages distributed like they are today, because modern browsers depend on the ALPN extension to determine weather to use http/1.1 or http/2 defaulting to 1.1.

This proposal aims to extends the current `net/ssl` package with some optional and backwards-compatible constructs to enable the adoption of ALPN.

# Detailed design
The term 'protocol' or 'protocol name' is used to mean a non-empty `String` with a size between 1 and 2^8-1 bytes.

A `String` that encodes many protocol names sequentially is referred to as a '*protocol list*' or '*protocol name list*'.
Admittedly, the term 'list' can be a bit confusing when referring to a `String`.

The reason it is chosen here is for consistency with [RFC7301](https://tools.ietf.org/html/rfc7301),
where it is referred to as 'ProtocolNameList'

The protocol names in a *protocol name list* are ordered by descending preference.

A *protocol list* is made up of the concatenation of one or more protocol names prefixed with the byte size of the protocol name.

`String.from_array([as U8: 2; 'h'; '2'; 8; 'h'; 't'; 't'; 'p'; '/'; '1'; '.'; '1'])` would be a valid protocol list for the protocols `["h2"; "http/1.1"]` (*notice the 2 and 8 denoting the length of the protocol name*)

Support for the ALPN extension was added to OpenSSL in version 1.0.2.
As ponyc supports linking with earlier versions, some of the functionality must be guarded by `ifdef` checks.

Add primitives `ALPNNoAck` `ALPNWarning` `ALPNFatal` and the type alias `ALPNProtocolName is String val`
Add type alias `ALPNMatchResult is (ALPNProtocolName | ALPNNoAck | ALPNWarning | ALPNFailure)`
Add `ALPNProtocolNotify` and `AlPNProtocolResolver` interfaces.
Add `ALPNStandardProtocolResolver` implementation
Add `alpn_set_resolver` and `alpn_set_client_protocols` to SSLContext
Add `alpn_selected` function to SSL, returning the negotiated protocol or None

```pony
type ALPNProtocolName is String val
primitive ALPNNoAck
primitive ALPNWarning
primitive ALPNFatal

type ALPNMatchResult is (ALPNProtocolName | ALPNNoAck | ALPNWarning | ALPNFatal)

interface ALPNProtocolResolver
  fun box resolve(client_protocols: Array[String] val): ALPNMatchResult

interface ALPNProtocolNotify
  fun ref alpn_negotiated(conn: TCPConnection ref, protocol: (String val | None)): None
```

```pony
class SSLContext
  ...
  fun ref alpn_set_resolver(resolver: ALPNProtocolResolver box): Bool
  fun ref alpn_set_client_protocols(protocols: Array[String] box): Bool
```

*The functions added to `SSLContext` return a bool indicating, weather ALPN is supported and the operation was successfull*

```pony
class SSL
  ...
  fun box alpn_selected(): (String val | None)
```

## Resolver
For servers to use the ALPN extension, one needs to pass an instance of `ALPNProtocolResolver` to `SSLContext.alpn_set_resolver`

When a client tries to connect with the ALPN extension enabled, the `ALPNProtocolResolver.resolve` function is called with an Array of *protocol names* the client advertised.

If a `ALPNProtocolName` is returned, that name will be used as the negotiated *protocol name* and be propagated back to the client,
even if it was not part of the initial set of *protocol names* provided by the client.

If the name is empty or longer than 2^8-1, the connection will be terminated.

If `ALPNNoAck` is returned, the connection will be continued without defining a protocol.

If `ALPNFatal` or `ALPNWarning` is returned, the connection is cancelled

This behaviour is analogous to the usage of `SSL_TLSEXT_ERR_OK`, `SSL_TLSEXT_ERR_ALERT_WARNING`, `SSL_TLSEXT_ERR_ALERT_FATAL` and `SSL_TLSEXT_ERR_NOACK`

### Standard Resolver
It is a bit tedious to have to implement a custom resolver every time one uses ALPN,
although the resolver pattern helps to abstract all the pointer manipulation away from the user while staying highly flexible.

To address this concern, there is an `ALPNStandardProtocolResolver` that works akin to the OpenSSL function `SSL_select_next_proto`:
It takes a list of protocols expected by the server and tries to resolve to the first protocol in that list that is also advertised by a client.
If no such protocol can be found, the resolver can optionally settle for the first protocol advertised by the client.

Reference implementation:
```pony
class ALPNStandardProtocolResolver is ALPNProtocolResolver
  """
  Implements the standard protocol selection akin to the OpenSSL function `SSL_select_next_proto`.
  """
  let supported: Array[String] val
  let use_client_as_fallback: Bool

  new val create(supported': Array[String] val, use_client_as_fallback': Bool = true) =>
    supported = supported'
    use_client_as_fallback = use_client_as_fallback'

  fun box resolve(advertised: Array[String] val): ALPNMatchResult =>
    for sup_proto in supported.values() do
      for adv_proto in advertised.values() do
        if sup_proto == adv_proto then return sup_proto end
      end
    end
    if use_client_as_fallback then
      try return advertised.apply(0)? end
    end

    ALPNWarning
```

## Client Protocol List
For clients to use the ALPN extension, one needs to pass a list of protocol names to advertise to the server to `SSLContext.alpn_set_client_protocols`


## Notify
The `notify` instance passed to `SSLConnection.create` can optionally implement the `ALPNProtocolNotify` interface.

The `ALPNProtocolNotify` interface informs client and server connections of the negotiated protocol.

`ALPNProtocolNotify.alpn_negotiated` should be right called after `TCPConnectionNotify.connected`, even if ALPN is not supported or used.
In that case a None value will be passed.

It is not called, if the protocol resolver produces an ALPNFailure.

# How We Teach This
Acceptance of this proposal would not require existing guides to be altered, nor changing how new users are taught.

The API documentation for the `net/ssl` package on stdlib.ponylang.org needs to be updated.

As the usage of ALPN is (at the moment at least) a fairly specific requirement, the appropriate docstrings on the added functions of the public API of this package should suffice.

# How We Test This
A set of unit tests will validate the that *protocol name lists* are encoded and decoded correctly
and errors are raised appropriately, when trying to encode or decode malformed data.

The behaviour of `ALPNStandardProtocolResolver` will also be validated using unit tests.

Further, we should validate that programs using this feature compile and run as expected on all supported versions of OpenSSL.

Other than that, the burden of testing lies with the OpenSSL project.

# Drawbacks
* Adds inconsistency into applications compiled with different OpenSSL versions, as versions below 1.0.2 will result in useless stubs

* Resolver pattern is more complex to implement than a simple `Array[String]` to pass to `SSL_select_next_proto` __(see [Standard Resolver](#standard-resolver))__

* Adds a `match` statement when a SSLConnection is established to check for the `ALPNProtocolNotify` interface, which might impact performance adversely.

# Alternatives
Alternatively to the Protocol Resolver pattern, the `SSL_select_next_proto` function could be used.
This would result in servers providing multiple protocols ordered by descending preference.
Although this is a much simpler approach, it is also very limiting, as it makes custom logic and constraints impossible.

The Protocol Resolver in contrast is fairly complex, but lifts as much of the OpenSSL specific logic into the pony system and can be abstracted however one sees fit.

An immediate alternative for users of the pony language looking to build applications utilizing this extension is to use a customized `net/ssl` package for their applications.

Alternatively to using empty stubs for OpenSSl versions below 1.0.2 the support for previous versions could be dropped to provide a more consistent experience to users.

# Unresolved questions
None

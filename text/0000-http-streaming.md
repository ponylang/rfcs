- Feature Name: http-streaming
- Start Date: 2016-12-12
- RFC PR:
- Pony Issue:

# Summary

Rewrite `package/net/http` to improve memory efficiency and support streaming in various forms.

# Motivation

The current design of the http client and server packages assumes that all payloads are relatively small and that all the responses in progress, across all sessions, can be contained in server memory at once.  This fails when the payloads are large files.  For example:

* A stereo MP3 file occupies about 1 megabyte for every minute of audio.  A 3-minute Pop song therefore requires 3 MB.  A 20 minute symphony movement requires 20 MB.  And video can be 10 times larger per minute.

* Buffering all of this data before sending even the first byte delays transmission needlessly, in addition to consuming a lot of memory.

* This problem has to be solved before the Pony http package can be used to build WebDav or media server applications.

The HTTP protocol specification provides several ways around this problem.  One is simply to send the body data in smaller pieces, allowing TCP buffering semantics to deliver the long bytestream to the other end.  No changes to the headers are required.  The other, for use when the `Handler` really does not know the total length of the data in advance, is Chunked Transfer Encoding, where the response body is sent in smaller pieces, each with its own length header.  No `Content-Length` header is used at all in this case.

This RFC proposes implementing both of these mechanisms in the Pony stdlib `net/http` package.

# Detailed design

The primary philosophy to be applied in both the client and the server is to get rid of data as soon as possible, passing it on to whatever the next stage in processing is.

Streaming can go in either direction, whether for uploading files in a WebDav application, or downloading files in WebDav or media streaming.  Luckily, the existing Pony code already has this general purpose abtraction in the `Payload` class.  The current implementation of `Payloas` works like this:

1. Create an empty `Payload`
2. Put data into it with one or more `add_chunk` calls
3. Send the completed `Payload` over the `TCPConnection`.
4. Pull data out with a single call to `get_body`

This is fundamentally incompatible with streaming operations.  The redesign will make http exchanges on `GET` and `POST` operations much more like all the other Pony file and network operations which use a *push* style:

1. Initialize an exchange, setting headers
2. Feed data into the `Payload` with `add_chunk`
3. The other end receives `Notifier.apply` calls as chunks arrive.
4. The sender calls `Payload.close()`
5. The receiver gets `Notifier.closed()`

Any desired packaging into convenient bundles, when the data is known to be small (for example, simple JSON strings) has to operate *above* ths streaming level.

## Changes to Payload handling

References below to "the `Handler`" refer to both `RequestHandler` and `ResponseHandler` interfaces.

1. Add a new funtion `Payload.set_size()` to explicitly specify the body size in advance.  (Can current behavior continue if this function is never called?)  Possible parameter values are:
    * `None` => Size is unknown so use Chunked Transfer Mode.  Generate a "Transfer-Encoding: chunked" header immediately.
    * `USize` => Size is known.  Generate a "Content-Length: nnn" header immediately.  This is possible when the response comes from a file and the file system allows for size queries.

2. Implement Chunked Transfer Mode.  If chunked mode has been indicated by the `Payload.set_size()` call, data added by `Payload.add_chunk` will be immediately transmitted with in the incremental format specified for chunked transfer encoding consisting of a length in hex, CRLF, the data, and another CRLF.

3. Stream large responses even when size is known.  If `Payload.set_size` is called with a "large" value (over 100KB?), data form `Payload.add_chunk' is accumulated only up to an established "buffer size" and then transmitted.  These bufferfuls do not need to have lengths prefixed, as that would have already been accounted for by the Content-Length header.

4. All headers are transmitted the first time any body data needs to be sent, in either chunked or "large body" streaming modes.  (New internal flag `var _headers_sent: Bool = false`)

5. Observe TCP backpressure, meaning that the channel is unable to accept more data, in the form of 'throttled' notifications.  This needs to be communicated back to the `Handler` so it can suspend reading from the data source.

Yet to be determined:

1. Is the `Payload.get_body` function still usable for small payloads?

## Changes to the Server

1. `_RequestHandler.apply()` can be called more than once.

2. Inhibit pipelining of requests while a streaming response is in progress.  Since processing of a streaming response can take a relatively long time, acting on additional requests in the meantime does nothing but use up memory. And if the server is being used to stream media, it is possible that these additional requests will themselves generate large responses.   Instead just let the requests queue up until a maximum queue length is reached (a small number) at which point back-pressure the inbound TCP stream.  There are three ways to accomplish this:

    1. Remove pipelined dispatch functionality entirely.  Consider that in the very common case of fetching data from single files in the file system, or from an already-open database, the file system can be an order of magnitude *faster* than the network connection back to the client, so any opportunity for speedup is limited.  Plus there is the increased overhead of more file handles open at once, and RAM usage.  Many browsers do not make use of this mode anyway.

    2. Add a parameter to `Server.create` to disable pipelining on all sessions.  Presumably the HTTP server main program knows if it is going to be serving large files or not.

    3. Automatically inhibit pipelining during processing of any request where either of the following happen (but see _Questions_ below):
        * `Payload.set_size(None)` is called
        * `Payload.set_size` is called with a "large" value (over 100KB?  Tunable?)

Questions:

1. Since it is the `RequestHandler` that determines whether a response will trigger streaming behavior, what if other requests have already been dispatched _after_ the dispatch of this one, but before the `RequestHandler` has had a chance to call `Payload.set_size()` to possibly block subsequent dispatches?

## Changes to the Client

1. `_ResponseHandler.apply()` can be called more than once.  Add `_ResponseHandler.closed()` to be called when all data has been received.

# How We Teach This

HTTP streaming and Chunked Transfer Encoding are parts of the HTTP standard.

Existing documentation for the HTTP package is sparse, coming entirely from the source code doc strings. So the doucmentation will update automatically. Adding more will be an improvement, especially in describing *how* to use the package, rather than just a list of types and functions.  The example might be improved to use the new features.

# How We Test This
```
How do we assure that the initial implementation works? How do we
assure going forward that the new functionality works after people
make changes? Do we need unit tests? Something more sophisticated?
What's the scope of testing? Does this change impact the testing
of other parts of Pony? Is our standard CI coverage sufficient to
test this change? Is manual intervention required?

In general this section should be able to serve as acceptance
criteria for any implementation of the RFC.
```
# Drawbacks

1. Changes to existing clients in the way Responses are delivered, even for "simple" cases.

# Alternatives

What is the impact of not doing this?
None is not an acceptable answer. There is always to option of not implementing the RFC.

# Unresolved questions

What parts of the design are still TBD?

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

## Backpressure

Backpressure is used in media streaming, for example. Mp3 data is 'consumed' in the client at a rate of about 17KB/second. Video data goes considerably faster. Back on the server, a file is being read as fast as the file system can go. The network can transfer the data at somewhere in between those speeds. To prevent RAM being consumed all along the path to buffer up stuff which has been read from the file but not yet 'played' on the client, there has to be a way for the client to signal "stop sending until I catch up". So the HTTP client code has to have a way to do that, which causes the TCPConnection actor to stop reading from the socket. The underlying network code then stops sending ACK packets and eventually the server end of TCP stops sending. The "throttled" event then happens on the server side, which has to be communicated to the HTTP session actor so it will stop reading from the disk file.

Then when the client catches up, it has to reverse this whole process, eventually causing the server to start reading from the file again.

Without this mechanism, RAM consumption in both client and server will balloon out of control. This is particularly bad on the server which might be handling hundreds of these connections simultaneously. The approach is "leave the data on disk until you know you can get rid of it".

## Transfer Modes

The primary philosophy to be applied in both the client and the server is to get rid of data as soon as possible, passing it on to whatever the next stage in processing is.

Streaming can go in either direction, whether for uploading files in a WebDav application, or downloading files in WebDav or media streaming.  Luckily, the existing Pony code already has this general purpose abtraction in the `Payload` class.  The current implementation of `Payload` works like this:

1. Create an empty `Payload` and set headers
2. Put data into it with one or more `add_chunk` calls
3. Send the completed `Payload` over the `TCPConnection`.
4. Pull data out with a single call to `get_body`

This is fundamentally incompatible with streaming operations.  The redesign will make large http exchanges on `GET` and `POST` operations much more like all the other Pony file and network operations which use a *push* style.  To manage this we introduce three *Transfer Modes*:

1. **OneshotTransfer**.  This is the current mode, useful for small messages.  If the new `Payload.set_length` function is not called, this is the mode that will be used.

2. **StreamTransfer**.  This is a new mode used for large payload bodies where the exact length is known in advance, such as for most WebDav and media transfers.  It is selected by calling `Payload.set_length` with a large integer bytecount.  On the TCP link this is indistinguishable from Oneshot mode other than the value of the `Content-Length` header is large.

3. **ChunkedTransfer**.  This is a new mode for cases where the payload length can not be known in advance, but is likely to be large.   It is selected by calling `Payload.set_length` with a parameter of `None`.  On the TCP link this mode can be detected because there is no `Content-Length` header at all, being replaced by the `Transfer-Encoding: chunked` header.  In addition, the message body is separated into chunks, each with its own bytecount.

The general procedure using the new interface is:

1. Create an empty `Payload`, and set headers
2. Call `Payload.set_length`
2. Feed data into the `Payload` with `add_chunk`
3. The other end receives `apply` notification as chunks arrive.
4. The sender calls `Payload.close()`
5. The receiver gets `closed` notification

## Changes to Payload handling

References below to "the `Handler`" refer to both `RequestHandler` and `ResponseHandler` interfaces.

1. Add a new funtion `Payload.set_size()` to explicitly specify the body size in advance.  (Can current behavior continue if this function is never called?)  Possible parameter values are:
    * `None` => Size is unknown so use Chunked Transfer Mode.  Generate a "Transfer-Encoding: chunked" header immediately.
    * `USize` => Size is known.  Generate a "Content-Length: nnn" header immediately.  This is possible when the response comes from a file and the file system allows for size queries.

2. Implement Chunked Transfer Mode.  If chunked mode has been indicated by the `Payload.set_size()` call, data added by `Payload.add_chunk` will be immediately transmitted with in the incremental format specified for chunked transfer encoding consisting of a length in hex, CRLF, the data, and another CRLF.

3. Stream large responses even when size is known.  If `Payload.set_size` is called with a "large" value (over 100KB?), data form `Payload.add_chunk' is accumulated only up to an established "buffer size" and then transmitted.  These bufferfuls do not need to have lengths prefixed, as that would have already been accounted for by the Content-Length header.

4. All headers are transmitted the first time any body data needs to be sent, in either chunked or "large body" streaming modes.  (New internal flag `var _headers_sent: Bool = false`)

5. Be able to both create and respond to TCP backpressure, meaning that the channel is unable to accept more data, in the form of 'throttled' notifications.  This needs to be communicated back to the `Handler` so it can suspend reading from its data source.  For consistency, the function names in TCPConnection could be copied for this mechanism.
    * `throttle()` to pause delivery of `apply()` calls
    * `unthrottle()` to resume delivery of `apply()` calls


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

HTTP streaming and Chunked Transfer Encoding are parts of the HTTP standard so we do not to describe that.

Most of the stdlib packages have no external documentation beyond the automatically generated web pages that get extracted from the doc-strings. But in the source code there is sometimes quite extensive information in comments. For example, net/TCPConnection has a long discussion of how backpressure works. Some files even have little examples in them. That would be easy enough.

Updating the examples/httpserver and client code could go a long way.

HTTP servers can get pretty complicated. I don't know that we want to get into all the ways that a whole Server can be written, with dispatching of URL fragments, etc. yet. I have used the cowboy http package in Erlang, and it had an extensive pattern matching/dispatch function.

# How We Test This

The existing `packages/net/http/_test.pony` does not currently test `http` operations at all.  It is an extensive test of the URL generation and parsing code however, which would not be changed by this project.

I am not sure whether the automated Pony test system could deal with two interacting programs, but:

* The program at `examples/httpget/httpget.pony` uses the *pull* model to fetch data from some server specified in the command line.  This would require a small change to use the *push* model instead.

* The program at `examples/httpserver/httpserver.pony` also uses the old interface and would have to be slightly modified.

## Backpressure

The existing `examples` programs deal with very small packages of information, which is not enough to test that the TCP backpressure mechanism is being used properly.

For testing, an arbitrary amount of synthetic data could be generated, simulating reading from a file. This way the test would not require the presence of any external files, and the amount of data transfered could be changed to test out different buffering thresholds and the backpressure mechanisms. Backpressure can be tested by having the receiving end stall for a few seconds with a timer so that all the TCP buffers fill up and the backpressure notifications happen. When the timer expires and the receiver starts reading again, the reverse should happen.

# Drawbacks

1. Changes to existing clients in the way Responses are delivered, even for "simple" cases.

# Alternatives

If these changes are not done, it would remain impossible to write a serious WebDav or media server using the `net/http` package.  (For example, something like NextCloud, currently written in PHP, or LogitechMediaServer, written in Perl.)  While the current code might work in a limited test with one user and an MP3 file, it would be quite slow and quickly run out of memory under a realistic load.

# Unresolved questions

1. Is it possible to maintain the existing *pull* interface as a layer on top of the new *push* interface?

2. How to deal with pipelining.

3. What is a good *flush buffer* threshold?  Should it be tunable?

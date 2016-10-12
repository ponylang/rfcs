- Feature Name: tcp must be connected
- Start Date: 2016-09-25
- RFC PR: 
- Pony Issue: 

# Summary

Verify TCP Connections are open before allowing data to be written.

# Motivation

Prevent subtle bugs and potential runaway memory usage that can be introduced by being unfamiliar with the internals of the `TCPConnection` class.

# Detailed design

Currently in `TCPConnection` 3 write methods check before that the connection isn't closed before trying to write. The 3 methods are `write`, `writev` and `write_final`. This prevents TCPConnection from buffering data if other actors send it write messages after a connnection is closed. 

However, you can start writing data to a connection without it being connected. Until a connection is established, that data will be buffered. If the connection is never opened and other actors continue to write to connection, eventually memory will be exhausted.

I propose to verify that a connection has been established before attempting to write to the underlying socket. In particular, in `write`, `writev` and `write_final`, the existing:

`if not _closed then`

should be changed to

`if _connected and not _closed then`

# How We Teach This

That `write`, `writev` and `write_final` might silently discard data should be noted in the class docstring as well as the doc string for each method in question.

Given that the change to make data get silently tossed and that someone might be inadvertently relying on that, in addition to updating the documentation, we should be sure to make the change and its ramifications are clear in commit message and release notes.

# Drawbacks

This might break existing code. Its possible to write programs that will start writing to the connection before its connected but that will connect.

Additionally, we are adding a check that will be run on every write call that otherwise wouldn't and could impact on performance. However, if this is a serious concern then we should have a conversation about removing the `_closed` check as well.

# Alternatives

Leave functionality as is and update documentation to call out the danger of not checking to see if a connection has been established before writing to it.

# Unresolved questions

None

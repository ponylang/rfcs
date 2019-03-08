- Feature Name: tcpconnection-hard-close
- Start Date: 2019-03-03
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Offer a way to immediately hard close a `TCPConnection`.

# Motivation

It is plausible that one may want to immediately hard close the `TCPConnection`
from within the methods on `TCPConnectionNotify`. Currently however, it is not
possible to hard close the connection as `TCPConnection.close()` only performs a
hard close if the connection is muted. Muting the connection however is only
available via the `TCPConnection.mute()` behavior that is run asynchronously.
Hence one cannot call `conn.mute()` followed by `conn.close()` in order to hard
close the connection.

# Detailed design

The existing private method `fun ref _hard_close()` would be made public (`fun
ref hard_close()`).

# How We Teach This

This new method should be noted in the changelog.

# How We Test This

A code review should suffice as this would be trivial.

# Drawbacks

I am currently unaware of any drawbacks.

# Alternatives

One alternative would be to introduce a new method `fun ref mute_now()` on
`TCPConnection` which would allow the connection to be muted immediately. If
this method were implemented, a call to the method `TCPConnection.close()` would
also achieve the hard close.

Another alternative is to not implement this and point out that a similar result
is achievable via a call to `TCPConnection.mute()` and subsequently to
`TCPConnection.dispose()`. This would however not be immediate.

# Unresolved questions

If the alternative was implemented, would it be useful to introduce `fun ref
unmute_now()` as a counterpart?

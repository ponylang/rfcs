- Feature Name: Require programmer to implement network failure handling
- Start Date: 2016-10-20
- RFC PR: https://github.com/ponylang/rfcs/pull/50
- Pony Issue: https://github.com/ponylang/ponyc/issues/1390

# Summary

Remove default implementations currently provided for failures on `TCPConnectionNotify`, `UDPNotify` and `TCPListenNotify`. 

# Motivation

Prevent Pony users from creating "silent failure" scenarios with their network code. `TCPConnectionNotify`, `UDPNotify` and `TCPListenNotify` will all, by default, silently eat connection failures.

# Detailed design

Remove the default implementation method bodies from:

- `TCPConnection.connect_failed`
- `UDPNotify.not_listening`
- `TCPListenNotify.not_listening`

By removing the default implementation from each of these, users will be forced to implement error handling. This means if they want to silently fail, they have to opt in to that.

To me, given the lack of familiarity that many have with async io, I think this "opt in to ignoring errors" would be a good pattern for us to adopt in the standard library in general.

# How We Teach This

Slight update to docstrings indicating why the failure methods are required. Otherwise, we let the compiler force people into implementing. Including an example of "how to implement ignore" as part of each docstring would also make sense.

# How We Test This

There's nothing to test as it will cause a compiler error to not implement.

# Drawbacks

This breaks all existing network code that is currently ignoring connection failures. Additionally, it forces users to implement a method on each of the notify types where previously, they didn't have to implement any. I think the advantage of having people opt in to 

# Alternatives

Leave as is but eventually develop better Pony standard library networking documentation particularly in the area of "how does this all work". However, users can ignore optional documentation whereas if we adopt this RFC, the compiler will force them to find the appropriate documentation (the docstring).

# Unresolved questions

How does this impact on [RFC 16](https://github.com/ponylang/rfcs/blob/master/text/0016-tcp-must-be-connected.md)?

I think a reasonable case can be made that RFC 16 should be reversed if this is adopted. We can assume that the user is aware of the dangers of ignoring connection failure and stop pending time checking for it during normal operations. I'm in favor of reviewing TCPListener, TCPConnection and UDPSocket for code that can be removed by this change and adding it in this RFC as part of the detailed design.

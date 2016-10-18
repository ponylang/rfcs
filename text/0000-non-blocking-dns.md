- Feature Name: Non-blocking DNS
- Start Date: 2016-10-18
- RFC PR:
- Pony Issue:

# Summary

DNS name resolution should be non-blocking (and asynchronous) from a user perspective.

# Motivation

Blocking name resolution could quickly exhaust the number of threads available for scheduling in a way that's difficult to manage and limits concurrency.

# Detailed design

DNS name resolution is used in a couple of places.

The network connection and listener actors are straight-forward to rework for asynchronous name resolution: instead of immediately going into the "connecting" and "listening" states respectively, the initial state would be "resolving".

The `DNS` primitive and `IPAddress` both assume blocking DNS name resolution in their APIs. These should be changed to promise-based APIs:
```pony
let p1: Promise[Array[IPAddress]] = IPEndpoint(host, service).resolve(auth)
let p2: Promise[(String, String)] = ip_address.reverse_lookup(auth)
```

# How We Teach This

This should not change much for the end-user, but it's important to note in the documentation that resolution blocks an execution thread.

# How We Test This

This will require some minor changes to the network test code.

# Drawbacks

While this is unlikely to cause big problems for users, it does potentially break existing code.

# Alternatives

None considered.

# Unresolved questions

The actual implementation of asynchronous name resolution is currently unresolved, but a first version could simply spawn an actor which would then make a blocking call (status quo), or maintain a thread-pool dedicated to this task. The end goal might be to have a complete implementation of DNS name resolution written in Pony itself.


- Feature Name: Send arbitrary messages to notify classes
- Start Date: 2017-06-03
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Update existing standard library classes that have "notify" classes that allow for programmer specialization, for example, `TCPConnnection` with its `TCPConnectionNotify` class, to allow to arbitrary messages and data to be sent to the notify class.

# Motivation

The basic "notify" pattern works well in Pony. You can encapsulate some standard handling of resources like standard input or TCP connection into an actor and the programmer can specialize what happens at certain points during the lifecycle. For simple use cases, this works fine. However, in a more complex scenario, problems arise.

I'm going to discuss the problems from the perspective of what we've needed to do at Sendence. Please note, however, that community members have raised the same issue via IRC and other channels, so this isn't a Sendence specific problem.

When notify class instances become stateful and that state needs to be updated, there is no way to do that within the existing system. If I have a TCPConnectionNotify instance that is initialized with some state and eventually that state needs to be updated by other actors in the system, there is no way to do that using TCPConnection. Our solution at Sendence has been to "fork" the TCPConnection class to support a new behavior on the actor and a corresponding method on the notify. This isn't an ideal scenario. We should have a means of allowing the programmer to update state in a notifier (or otherwise have the outside world communicate with it) without having to forever maintain their own custom "forked" version.

If additional functionality is added to `TCPConnection`, the forked version wouldn't be able to take advantage of that without change. Same goes for bug fixes etc.

While most of Sendence's pain (and the pain that has come up from the community) has related to network code like `TCPConnection`, there are additional actors that follow the same pattern.

# Detailed design

I propose that we add a `deliver_to_notify` behavior to the following classes:

- `Stdin`
- `TCPConnection`
- `TCPListener`
- `UDPSocket`
- `HTTPServer`
- `ProcessMonitor`
- `SignalHandler`
- `AnsiTerm`
- `Readline`
- `Timer`

The corresponding "notify" classes would, in turn, have a `handle_message` method added. 

Each `deliver_to_notify` method would look like:

```pony
be deliver_to_notify(message: Any #send) =>
  _notify.handle_message(this, message)
```

In turn, each of the "notify" classes would have the default implementation like:

```pony
fun ref handle_message(conn: TCPConnection ref, message: Any #send) =>
  None
```

Additionally, `SSLConnection` needs to be updated to pass through the `handle_message` to its wrapped `TCPConnectionNotify` object.

To make use of this, a programmer would then override handle message to handle arbitrary messages they might need to receive:

```pony
fun ref handle_message(conn: TCPConnection ref, message: Any #send) =>
  match message
  | let m: MyMessageType val =>
    // my custom message logic here
  else
    // unknown message
    None
  end
```

# How We Teach This

This feature would most likely be used by more "advanced" Pony users. As such, I don't think it needs to be included in the tutorial. Pony Patterns might eventually be developed that feature the use of the RFC. However, I don't think any are required for this to be merged. 

I suggest that adding object level documentation to the affected standard library classes is sufficient for "new" users to discover. For "existing" user discovery, the addition of this feature should be highlighted in the release notes for whatever Pony release incorporates these changes.

Please note that for "object level documentation", this should include a basic example of "sending a message" to a notifier (for each affected object).

# How We Test This

Given that the implementation is very straightforward and simple (it's a pass-through), I don't think any tests need be written. Code review should suffice.

# Drawbacks

This is not the ideal solution. Ideally, Pony would allow objects enclosed within an actor to directly receive messages. Sylvan and I have discussed this idea under the heading of "async lambda". If "async lambda" existed, it would allow any class receive messages. 

This approach proposed in this RFC only works where coded into a given class. Additionally, the approach is fundamentally unsafe in that it's a runtime dispatch of messages and can't be statically validated.

# Alternatives

We could wait for Sylvan to open an "async lambda" RFC and for it to eventually be implemented. However, that could be a considerable amount of time and the pain points would exist in the meantime.

# Unresolved questions

Naming to add is an open question. `deliver_to_notify` and `handle_message` are a "first-pass" naming.

- Feature Name: Change standard library object capabilities pattern
- Start Date: 2022-02-02
- RFC PR: https://github.com/ponylang/rfcs/pull/196
- Pony Issue: https://github.com/ponylang/ponyc/issues/4028

# Summary

Change the pattern for how object capabilities are used in the standard library.

# Motivation

Object capabilities play an important role in Pony's security story. Developers can via a combination of disallowing the use of FFI within a given package and object capabilities be assured that 3rd-party libraries they use aren't doing unexpected things like opening network sockets.

Joe Eli McIlvain and I spent some time reviewing the existing usage of object capabilities and came away concerned. We believe the existing standard library pattern is:

- Error prone for beginning Pony programmers
- Encourages passing around AmbientAuth everywhere in a way that negates the advantages of using object capabilities and only leaves the disadvantages

## Current pattern

The `backpressure` package in the standard library is an excellent package to study to see the core of the current pattern.

```pony
primitive ApplyReleaseBackpressureAuth
  new create(from: AmbientAuth) =>
    None

type BackpressureAuth is (AmbientAuth | ApplyReleaseBackpressureAuth)

primitive Backpressure
  fun apply(auth: BackpressureAuth) =>
    @pony_apply_backpressure()

  fun release(auth: BackpressureAuth) =>
    @pony_release_backpressure()
```

We have:

- functions that you need an authorization to use

`fun apply(auth: BackpressureAuth)`

- a specific authorization type for the functions in question

`primitive ApplyReleaseBackpressureAuth`

- a type union representing a union hierachy of authorities that are acceptable to using the function

`type BackpressureAuth is (AmbientAuth | ApplyReleaseBackpressureAuth)`

In the example above, our hierachy of authorities is limited to two. Studying the authorities in the `net` package can show deeper authority hierachies that result in a type union that has more members and specific authorization objects that have constructors that accept a union of types, however, the pattern as seen in `backpressure` holds across the standard library.

## Error prone for beginners

When users see a type union like FooAuth, they sometimes believe that it is a concrete type. When combined with an incorrect understanding of how the `as` keyword works, this can lead to code like:

```pony
use "net"

actor Main
  new create(env: Env) =>
    TCPListener(env.root as TCPListenerAuth,
        recover MyTCPListenNotify end, "", "8989")
```

The user believes that the `env.root as TCPListenerAuth` is creating a more specific auth `TCPListenerAuth` when in fact, it is passing `AmbientAuth` along to the `TCPListener` call.

## Encourages passing around AmbientAuth

By having AmbientAuth and less specific auths in the [authority hierachy](https://tutorial.ponylang.io/object-capabilities/derived-authority.html#authority-hierarchies) accepted at the usage site, we are encouraging users to "take the easiest" route and pass AmbientAuth around.

This in turn means that we are doing extra work due to the exist of object capabilities but still effectively working with an ambient authority everywhere system like one has in most programming languages.

# Detailed design

The pattern change is rather limited in scope. Everything about the current pattern remains the same except for two changes. First, we switch the call site where an auth is needed to only accept a single, most specific auth. From our example above this would mean:

```pony
primitive Backpressure
  fun apply(auth: BackpressureAuth) =>
    @pony_apply_backpressure()

  fun release(auth: BackpressureAuth) =>
    @pony_release_backpressure()
```

becomes

```pony
primitive Backpressure
  fun apply(auth: ApplyReleaseBackpressureAuth) =>
    @pony_apply_backpressure()

  fun release(auth: ApplyReleaseBackpressureAuth) =>
    @pony_release_backpressure()
```

By doing this, we eliminate the need for the type union, so

```pony
type BackpressureAuth is (AmbientAuth | ApplyReleaseBackpressureAuth)
```

is no longer needed as the only reference to it has been removed.

The removal of the type union removes the possible incorrect usage with `as` seen in the motivation section. And the lack of ability to use a non-specific auth at the final call site encourages only passing around the most specific auth required.

Capability constructors like `ApplyReleaseBackpressureAuth` will remain unchanged whether they currently take a single auth to derive from:

```pony
primitive ApplyReleaseBackpressureAuth
  new create(from: AmbientAuth) =>
    None
```

Or like many in the `net` package, take more than one auth to derive from:

```pony
primitive NetAuth
  new create(from: AmbientAuth) =>
    None

primitive DNSAuth
  new create(from: (AmbientAuth | NetAuth)) =>
    None

primitive UDPAuth
  new create(from: (AmbientAuth | NetAuth)) =>
    None

primitive TCPAuth
  new create(from: (AmbientAuth | NetAuth)) =>
    None

primitive TCPListenAuth
  new create(from: (AmbientAuth | NetAuth | TCPAuth)) =>
    None

primitive TCPConnectAuth
  new create(from: (AmbientAuth | NetAuth | TCPAuth)) =>
    None
```

# How We Teach This

We will need to update examples in documentation in the standard library to account for this change as well as possibly, examples in the `examples` directory of the ponyc repo. The latter will be caught during standard CI testing. The former will require manual review of the documentation for each package impacted by this change.

The type unions at the call site are mentioned the [derived authority](https://tutorial.ponylang.io/object-capabilities/derived-authority.html) section of the tutorial and will need to be rewritten to the new pattern.

An example in the derived authority section of the tutorial is shown passing `AmbientAuth` into `TCPConnection`, this will also need to be updated.

A general overall reading of the derived authority section of the tutorial to make sure it reads well and still makes sense with the above changes should be done.

We can inform users of this breaking change via our standard mechanism of including "before" and "after" examples in the release notes.

# How We Test This

Existing tests as done on the command-line and in CI is sufficient to find any breakage in the standard library.

# Drawbacks

This is a breaking change and as such, should be taken seriously.

# Alternatives

There have been a large number of designs considered. Enumerating them in this RFC would be difficult given the current format for RFCs. The various approaches are detailed in the [Ponylang Zulip thread](https://ponylang.zulipchat.com/#narrow/stream/189959-RFCs/topic/object.20capabilities.20-.20preventing.20malicious.20general-auth-u.2E.2E.2E). Consensus formed in the thread around the approach in this RFC.

# Unresolved questions

None

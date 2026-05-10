- Feature Name: ip_address_classes
- Start Date: 2020-01-07
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Add classes representing IPv4 and IPv6 addresses to the `net` package.

# Motivation

Right now, the only way to interact with IP-addresses is either via string 
e.g. when constructing a `TCPConnection` or `TCPListener`, or when dealing with
`NetAddress`, which is wrapping the C `sockaddr` and is thus actually a representation
of the address of a (connected) socket. It is possible to get the contained IP address
right now only as `U32` in case of IPv4 or as `(U32, U32, U32, U32)` in case of IPv6.
Those representations are both very inconvenient to work with. E.g. it is especially hard to
create a proper string representation from them.

This RFC tries to overcome those inconveniences by introducing proper usable classes
but keep efficiency in memory-representation in mind. Trade-offs...

Having IP address classes will give us proper IP-address validation, easily created String representations, inspection of IP address properties.

# Detailed design

A class `IPv4Address` is added. Its internal state is a `U32` in network byte order.

```
class val IPv4Address is (Equatable[IPAddress] & Stringable & Hashable & Hashable64)
  let _addr: U32

  ...
```

A similar class `IPv6Address` is added. Its internal stats is a 4-element embed `Array[U32]`.

Those classes have constructors for creating instances from String and convenience constructors for some special addresses, like loopback, any or broadcast addresses.

They have methods for detecting if they are within a certain IP range (e.g. multicast, private etc.).

They also have methods for returning the addresses in other formats e.g. Strings, octets or similar.

`NetAddress` will return instances of those classes, in addition to the raw representations. Its internal state will not change, as it must be equivalent to `sockaddr_storage` and thus cannot be changed. The signature of the methods `ipv4_addr` and `ipv6_addr` to return an `IPv4Address` and `IPv6Address` respectively.
Additional methods (`ipv4_addr_raw`, `ipv6_addr_raw`) will be added that return the raw representation of the IP addresses in host byte order as the old `ipv4_addr` and `ipv6_addr` methods did,
in order to make the raw value available without additional allocation as it would be necessary with the new classes: 
`net_address.ipv4_addr().u32()` 
which might hurt performance if the compiler is not optimizing it away.

With this change, and some tiny tweaks to libponyrt, it is possible to make `NetAddress` Stringable, too.

A type alias `IPAddress` will be created:

```pony
type IPAddress is (IPv4Address | IPv6Address)
```

this way it is possible to handle a generic `IPAddress` using the methods common to both `IPv4Address`. and `IPv6Address`. It might be a valid alternative to use an interface `IPAddress` instead.

The API design has been heavily inspired by the python stdlib ipaddress module: https://docs.python.org/3/library/ipaddress.html

# How We Teach This

Proper class and method docstrings should be sufficient.

# How We Test This

Unit tests for constructing, parsing, validating ip addresses and range checks should be enough.

# Drawbacks

* Making use of an IP address requires an additional object allocation.
* Breaks existing code with regards to `NetAddress`.

# Alternatives

Create primitives for IP address handling that work directly on the raw representations `U32` for IPv4 and `U128` for IPv6 for which type aliases can be created. This way no allocations are needed, but we have a very non-OO and non-intuitive API and representation.

# Unresolved questions

Should the way for handling a generic IP address (IPv4 or IPv6) be via a type-union or an interface?
I.E.:

```pony
type IPAddress is (IPv4Address | IPv6Address)

// vs

interface val IPAddress
  new val from_string(ip: String)?

  new val loopback()

  new val any()

  fun string(): String iso^

  fun is_multicast(): Bool

  // ... and other range testing functions...

  fun eq(o: IPaddress): Bool

  fun hash(): USize

  fun hash64(): U64
```


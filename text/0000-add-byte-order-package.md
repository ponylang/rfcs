- Feature Name: add-byte-order-package
- Start Date: 2026-10-15
- RFC PR:
- Pony Issue:

# Summary

Add a `byte_order` package to the standard library with two primitives, `BigEndian` and `LittleEndian`, for stateless conversion between native integers and their wire representations.

# Motivation

The Pony stdlib has no stateless way to do byte-order conversion. If you have a `ReadSeq[U8]` and you want to read a U32 in big-endian order, you have two choices. You can spin up a `buffered.Reader`, which is stateful, allocates, and exists to walk chunks in a stream-processing pipeline. Or you can write the shifts and ORs yourself.

Neither of those is a good answer. `buffered.Reader` is the wrong tool — you're paying for state management and chunk-walking when all you need is four bytes assembled into a U32. Writing it by hand works, but you end up with the same handful of shift expressions copy-pasted across every protocol implementation, file format parser, and FFI interop layer in the ecosystem. That's the kind of thing a standard library is for.

This gap was identified back in 2017 in [ponylang/rfcs#112](https://github.com/ponylang/rfcs/issues/112). Joe and I discussed the shape of a solution there over the course of several years. The conclusion was clear: a separate package with stateless primitives, not modifications to Reader. `buffered.Reader`'s implementation is tied to its internal chunk-walking machinery. The byte-assembly logic is straightforward shifts and ORs. There's nothing worth lifting out. Write it fresh, leave buffered alone.

# Detailed design

The full implementation is in PR [#6290](https://github.com/ponylang/ponyc/pull/6290).

The package lives at `packages/byte_order`, separate from `buffered`. It contains two primitives: `BigEndian` and `LittleEndian`. Endianness is almost always known statically. Network protocols are big-endian. File formats specify theirs. A runtime parameter that picks the byte order at the call site would add a branch where there's no actual decision to make. Two primitives give you compile-time selection and zero overhead. And because both primitives have the same method signatures, code that needs runtime selection — a TIFF parser that checks a header flag to decide the byte order — can pass either primitive as a value and dispatch on type without needing differently named methods.

Read methods are generic over any `ReadSeq[U8]`. When the concrete type is `Array[U8]`, iftype specialization selects an optimized path that uses native-width loads and conditional byte swaps. The generic path uses shift-and-OR, which works for any `ReadSeq[U8]` — so if you're reading from something other than an array, it still works. Read methods take an optional `offset` parameter that defaults to 0. They're partial; they error on insufficient data.

Write methods push encoded bytes onto an `Array[U8]`.

Signed types delegate to the unsigned read and cast the result. Floats delegate to the unsigned read and call `from_bits`. The coverage is U16 through U128, I16 through I128, F32, and F64.

# How We Teach This

Package-level documentation is included in the implementation. The standard library docs site picks it up automatically. Release notes will include a code example showing basic usage.

# How We Test This

The implementation includes property-based tests — roundtrip, endian cross-checks, `ReadSeq` vs `Array` consistency, signed roundtrip, float roundtrip — and unit tests for known values, offset reads, and short-data errors. The full test suite is in PR [#6290](https://github.com/ponylang/ponyc/pull/6290).

# Drawbacks

I don't believe there are any. This is a small, stateless package that fills a real gap.

# Alternatives

The design alternatives — a runtime endianness parameter, modifying `buffered.Reader`, shipping as a third-party library first — were discussed and rejected on [ponylang/rfcs#112](https://github.com/ponylang/rfcs/issues/112) over the course of several years. The only real alternative is to not do this, and I don't think that's a good outcome for the ecosystem.

# Unresolved questions

None.

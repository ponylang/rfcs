- Feature Name: serialise-signature
- Start Date: 2017-03-26
- RFC PR: https://github.com/ponylang/rfcs/pull/87
- Pony Issue: https://github.com/ponylang/ponyc/issues/2147

# Summary

A `Serialise.signature` method, which returns a unique byte array for the current compiled Pony program.

# Motivation

The `serialise` package was primarily designed around the use case of serialising arbitrary objects for transmission between copies of the same Pony binary that are distributed over a network. However, there's another compelling use case to consider that can make use of the same mechanisms: serialising arbitrary objects to disk for later consumption by the same Pony binary.

However, this second use case poses an additional challenge: due to being serialised across a (possibly long) period of time, it becomes harder to operationally ensure that the same Pony binary is being used to deserialise the data as the one that serialised it.

Consider a program that wishes to cache some data to disk. Using the `serialise` package is an obvious choice if that data is for internal use only, but due to the possibility that a found cache file could have been serialised by a different binary of the same program, the program would want some mechanism for guarding against this possibility.

The most common way of doing this would be to prepend a "serialise signature" to the serialised data in the file, which was unique to the compiled binary of the program, and could thus be used to recognize whether a given cache file had been serialised by the same binary. If the serialise signature didn't match the one held by the deserialising binary, it could abort loading the cache file and reconstruct the data "from scratch" instead of using the cache.

This mechanism would not protect against a malicious attack (in which the attacker created a file with the expected serialise signature and malicious following data), but it would at least protect against an accidental reading of data which would be loaded as a corrupt data structure.

Actually, this same mechanism could also be quite useful even in the original use case of serializing objects between concurrent programs on a network. Even though you expect operationally to be using the same binary of the program, it could still be quite valuable to have an extra safeguard in case of operational issues that lead to different binaries of the program accidentally exhanging data with one another.

Since this feature would be useful in the general case for serialisation, and it's not clear to me how it would be implemented in the general case without some form of compiler/runtime-assisted introspection, it seems compelling to include it as a feature of the `serialise` package.

# Detailed design

The following primitive with the following function will be added to the `serialise` library:

```pony
primitive Serialise
  fun signature(): Array[U8] val =>
    """
    Returns a byte array that is unique to this compiled Pony binary, for the
    purposes of comparing before deserialising any data from that source.
    It is statistically impossible for two serialisation-incompatible Pony
    binaries to have the same serialise signature.
    """
```

Additionally, the following paragraph would be added to the existing warning in the `serialise` package docstring, about avoiding deserialising data from
a different Pony binary, or from untrusted sources.

```
The Serialise.signature method is provided for the purposes of comparing
communicating Pony binaries to determine if they are the same. Confirming this
before deserializing data can help mitigate the risk of accidental serialisation
across different Pony binaries, but does not on its own address the security
issues of accepting data from untrusted sources.
```

# How We Teach This

Serialisation isn't currently covered in the tutorial, or any Pony patterns, so the docstring changes noted above should be enough to teach this.

# How We Test This

It's not clear to me how we could add unit tests for this, other than exercising the `Serialise.signature` method to confirm that it returns a consistent byte sequence that is non-zero in length.

Testing across different compiled Pony binaries would probably have to performed manually.

# Drawbacks

* Additional compiler/runtime-dependent mechanisms to maintain for the `serialise` package.

# Alternatives

Leave it up to the user application to implement some 3rd-party scheme for identifying whether the same binary of the program was used to serialise some data.

# Unresolved questions

* How should we generate the signature? The easiest solution would be to generate a random byte sequence on every compile, and code-generate that into the program, but I'm also open to hearing ideas for deterministic signatures (that would yield the same result if compiling the same program again on the same platform with no changes), if that they aren't too difficult or hacky to implement.

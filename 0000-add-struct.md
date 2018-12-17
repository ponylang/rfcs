- Feature Name: add Python Struct-like primitive
- Start Date: 2018-12-16
- RFC PR:
- Pony Issue:

# Summary

Add ability to use format specification strings to convert between bytestreams and arrays of native Pony types and vice versa. Inspired by [Python struct](https://docs.python.org/3.7/library/struct.html)

# Motivation

Why are we doing this? What use cases does it support? What is the expected outcome?

When working with code that has to do both encoding and decoding between native types and bytestreams, I found myself wishing I could use something like Python's struct format string to specify the bytestream conversion rules.
Additionally, I think it is helpful to be able to specify the conversion in a concise format string that works for both encoding and decoding.

# Detailed design

`Struct` consists of two functions:
`pack(fmt: String, args: Array[(Bool | Number | String | Array[U8] val)], wb: Writer = writer): Array[ByteSeq] ?` which is used to pack arguments into a bytestream, and `unpack(fmt: String, rb: Reader): Array[(Bool | Number | String | Array[U8] val)] ?` which does the reverse.

It also uses the private type alias `type _Packable is (Bool | Number | String | Array[U8] val)`, which I'll use for the rest of the discussion, and the private helper `_ParseFormat(fmt: String)` which handles the format string parsing for both `pack` and `unpack`.

Under the hood, `Struct` uses the type conversion methods of `Writer` and `Reader` from the `buffered` package.
It might make sense to include the functionality from Struct as part of the `buffered` package, given this close dependency, and how closely related the two are.

Example usage:

```pony
// Use the same format specification string for both pack and unpack
let fmt_string: String = ">Iqd5ss5p"

try
  // Pack some data into a bytestream
  let byte_seqs = Struct.pack(fmt_string,
    [ 1024
      1544924117813084
      3.141592653589793
      "hello"
      "!"
      recover [as U8: 1;2;3;4;5] end
      ] )?

  // Unpack data from a bytestream
  let reader = Reader
  for bs in byte_seqs.values() do
    reader.append(bs)
  end
  let unpacked = Struct.unpack(fmt_string, consume reader)?

  // cast the returned arguments into types
  let fold = unpacked(0)? as U32
  let timestamp = unpacked(1)? as U64
  let pi = unpacked(2)? as F64
  let msg = unpacked(3)? as String
  let flag = unpacked(4)? as String
  let bytes = unpacked(5)? as Array[U8] val
end
```

One benefit of using Struct over performing the same conversions using the `Writer` and `Reader`'s type-to-bytes and bytes-to-type conversion functions is that it is much more concise, without reducing any functionality.

Another benefit is that format specification strings can be reused, as seen in the example. This can be helpful when creating custom serialisation and deserialisation functions for a class or complex type, for example.

# How We Teach This

The inspiration for this work is Python's `struct` built-in module. so initially i named it after it.

The documentation included should be enough to get most folks started with it, as the concept itself is similar to `printf` format strings, and to other similar conversion functionality in other languages.

The `pack` and `unpack` function names as well as the order of arguments is borrowed directly from the Python `struct` module.

The acceptance of this proposal would not require any reorganization of the Pony guides or how it is taught.

This feature could be reintroduced and taught to existing users via the weekly newsletter, and by including it in the documentation.
As it doesn't change the base functionality of `buffered`, it would not impact existing users whereas users looking for this functionality will be able to find it and use it directly.

# How We Test This

The initial implementation has unit tests.
I think given the variable nature of inputs and outputs, it would benefit from also being tested with `ponycheck` and `ponybench`.

I think that standard CI coverage will suffice for ongoing test coverage of this feature.

# Drawbacks
- It's possible to do all of what this package does with the Writer and Reader in the buffered package. In fact, the Struct primitive uses the Writer and Reader classes to do the real conversions.
- However... When writing a network format spec between Python and Pony, I found myself wishing I could use the Python struct format to specify the actual bytestream formatting rules.
  - Even more appealing was the idea of using the same format string on both sides. But perhaps that's a bit too Python<->Pony specific to be generally applicable.
- While this is really handy when converting from Pony to a bytestream, the other way around still feels a little clunky.
  Because the return type is Array[(Bool | Number | String | Array[U8] val)], when accessing the unpacked arguments, the user still has to explicitly cast to their target type.
  I'm not super happy about this part, but I don't have any good ideas on how to make this more user friendly. I'd be happy to incorporate any ideas or feedback you might have for this!
  e.g. (from one of the unit tests):
  ```pony
  let u1 = Struct.unpack(fmt1, consume r1)?
  h.assert_eq[U32](args1(0)? as U32, u1(0)? as U32)
  ```

# Alternatives

1. `Struct` could become part of `buffered` instead of being its own package.
2. We could add the `pack` and `unpack` functions directly to `Writer` and `Reader`
3. We could leave it out, in which case users may develop their own, use the [pony-struct](https://github.com/nisanharamati/pony-struct) package from github, or use the lower level conversion functions in `buffered`.

# Unresolved questions

There is room to improve the following:
- handling of output typing from `unpacked`
  - For example, a user could provide a constructor to `unpack` to return something more specific than an Array of all the possible return types (recall `type _Packable is (Bool | Number | String | Array[U8] val)`).
- there may be room to improve performance
  - Users may want to only parse a format string once, rather than each time it is used.
    This can be done by adding a class that is created with the format string, and provides `pack` and `unpack`.
- there may be room to improve error handling.
  At the moment, packing and unpacking may fail wherever `Writer` and `Reader` may fail, as well as when the format string and arguments don't match.

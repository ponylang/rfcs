- Feature Name: buffered_reader_read_until
- Start Date: 2016-09-19
- RFC PR:
- Pony Issue:

# Summary

Add a method on ``buffered.Reader`` that reads the buffer until a given byte is found.

# Motivation

Some protocols in the wild define their messages using a separator byte. Some
use null-terminated strings. With the current implementation of ``Reader``,
there is no easy way to read this kind of input. This RFC purpose is to provide
a simple and versatile way to extract this data.

# Detailed design

The implementation relies on a private method

```pony
fun ref _distance_of(byte': U8): USize ?
```

which has quite the exact same implementation as


```pony
fun ref _line_length(): USize ?
```

(https://github.com/ponylang/ponyc/blob/master/packages/buffered/reader.pony#L532)

The only difference is that it  searches for the provide byte' rather than '\n'.

It returns the distance from the current position in the buffer to the first
occurrence of the provided byte, or raise an error if that byte is not found.

``Reader`` then exposes a

```pony
fun ref read_until(byte': U8, greedy: Bool=true): Array[U8] iso^ ?
```

method that calls ``_distance_of`` and returns the data from the current
position to the byte. It raise if `byte` can't be found.

The ``greedy`` parameter tells if the separator byte is included in
the result (and incidently if it's consumed). This adds versatility for
corner cases without impacting the main use case.

## Usage example

```pony
String.from_array(reader.read_until(0)) // read a null-terminated string
reader.read_until(':') // read a field in a colon-separated chunk of data
reader.read_until(0, false) // read all the data before a small U32 i want to read. It's convoluted, I confess.
```

# How We Teach This

This has no impact on existing code. Add comprehensive method documentation
and use the method in the package doc.

# Drawbacks

None

# Alternatives

The RFC started from this refused [pull-request](https://github.com/ponylang/ponyc/pull/1239)
that addresses a narrower use-case. We deemed it too specific.

# Unresolved questions

The name of the method is maybe not satisfying, I think. Non-native english speaker here, tell us if
you can think of a better name.

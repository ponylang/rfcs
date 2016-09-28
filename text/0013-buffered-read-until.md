- Feature Name: buffered_reader_read_until
- Start Date: 2016-09-19
- RFC PR: https://github.com/ponylang/rfcs/pull/34
- Pony Issue: https://github.com/ponylang/ponyc/issues/1277

# Summary

Add a method on ``buffered.Reader`` that reads the buffer until a given byte is found.

# Motivation

Some protocols in the wild define their messages using a separator byte. Some use null-terminated strings. With the current implementation of ``Reader``, there is no easy way to read this kind of input. This RFC purpose is to provide a simple and versatile way to extract this data.

Example of protocols that would benefit from this feature:

- Postgresql : https://www.postgresql.org/docs/current/static/protocol-message-formats.html
  - some messages contain a null-terminated string in the middle (`ErrorResponse`, `ParmeterStatus`...)

# Detailed design

## API

``Reader`` exposes a

```pony
fun ref read_until(byte': U8): Array[U8] iso^ ?
```

method that returns the data from the current position to the first occurrence of the given ``byte'``. The terminating byte is read, but not append in the result. Raise an error if `byte'` can't be found.


## Implementation details

The implementation relies on a private method

```pony
fun ref _distance_of(byte': U8): USize ?
```

which has quite the exact same implementation as


```pony
fun ref _line_length(): USize ?
```

(https://github.com/ponylang/ponyc/blob/master/packages/buffered/reader.pony#L532)

The only difference is that it searches for the provided `byte'` rather than `'\n'`.

It returns the distance from the current position in the buffer to the first occurrence of the provided byte, or raise an error if that byte is not found.

## Usage example

```pony
String.from_array(reader.read_until(0)) // read a null-terminated string
reader.read_until(':') // read a field in a colon-separated chunk of data
```

## Test case

```pony
    let b = Reader

    b.append(recover [as U8: 's', 't', 'r', '1', 0] end)
    b.append(recover [as U8: 'f', 'i', 'e', 'l', 'd', '1', ';', 'f', '2', ';', ';'] end)
    h.assert_eq[String](String.from_array(b.read_until(0)), "str1")
    h.assert_eq[String](String.from_array(b.read_until(';')), "field1")
    h.assert_eq[String](String.from_array(b.read_until(';')), "f2")
    // read an empty field
    h.assert_eq[String](String.from_array(b.read_until(';')), "")
    // the last byte is consumed by the reader
    h.assert_eq[USize](b.size(), 0)
```

# How We Teach This

This has no impact on existing code. Add comprehensive method documentation and use the method in the package doc.

# Drawbacks

None

# Alternatives

- The RFC started from this refused [pull-request](https://github.com/ponylang/ponyc/pull/1239) that addresses a narrower use-case. We deemed it too specific.

- In a first version of the RFC, `read_until` accepted a second argument:

```pony
fun ref read_until(byte': U8, greedy: Bool=true): Array[U8] iso^ ?
```

to let the user decide if the separator is included into the result or kept in the buffer for the next read operation. We found that this was inconsistent with `line()`'s behaviour for a very little gain.

- In the discussion we asked whether we should be more general and add a way to split on more than one byte. We didn't find a protocol that requires a multiple-bytes separator other than CRLF. This special case is already handled by `line()`. We decided that the marginal gain does not worth the extra complexity of the API and implementation. This feature may be the object of a new RFC if the case raises.

# Unresolved questions

- The name of the method is maybe not satisfying, I think. Non-native English speaker here, tell us if you can think of a better name.

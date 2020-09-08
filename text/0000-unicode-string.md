- Feature Name: unicode-string
- Start Date: 2020-07-30
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Change the builtin String class to present a sequence of unicode codepoints as 4 byte numbers (U32) instead of a sequence of bytes. All conversions from a sequence of bytes to a String, or from a String to a sequence of bytes will require specifying a decoding or encoding respectively. The default encoding will be UTF-8, and Strings will be represented internally as a sequence of UTF-8 encoded codepoints. Provide encoders/ decoders for UTF-8, UTF-16, UTF-32, ASCII and ISO-8859-1 as part of the stdlib. Change the character literal to represent a single unicode codepoint and produce a UTF-32 codepoint value.

# Motivation

Unicode is an accepted standard for representing text in all languages used on planet earth. Modern programming languages should have first class support for unicode.

# Detailed design

Change the builtin String class to present of sequence of unicode codepoints as 4 byte numbers (U32). 
```
class val String is (Seq[U32] & Comparable[String box] & Stringable)
```
Where String functions took parameters of type U8 or returned values of U8, they will take or return values of type U32. All indexes will be interpreted as codepoints. Only functions that manage String allocated memory will continue to refer to bytes.

The following additional changes will be made to the String class:
1. The size() function will return the number of unicode codepoints in the string. A new byte_size() function will return the number of bytes.
1. The truncate() function will only support len parameter values less than the string size. The len parameter defines a number of codepoints. Add a resize() function to set the size of a string in bytes. This is needed for FFI calls where the _ptr is populated by the function, and the string length in bytes is provided by the function.
1. The utf32() function will be removed. It is redundant, and returns pair that includes a byte count that is no longer needed.
1. The insert_byte() function will be changed to insert_utf32()
1. The values() function will return an iterator over the string codepoints. Same as runes(). A new bytes() function will return an iterator over string encoded as bytes. The bytes() function will take a StringEncoder parameter.
1. A concat_bytes() function will be added to add a sequence of codepoints to the string from an iterator of bytes.
1. Change the internal implementation of String to replace the _size, _alloc and _ptr variables with an embedded Array.
1. Change 'fun val array: Array[U8] val' to 'fun array: this->Array[U8] box'. This is a superset of what we have now, and allows a readable "byte string" reference to a String ref, rather than requiring val.

Add whatever methods we need to add to Array[U8] that are restricted by A:U8 (e.g. read_u8) to make Array[U8] have everything that a "byte string" class needs.

Add traits StringEncoder and StringDecoder to the builtin package. Any function that produces a String from bytes, or produces bytes from a String must take a StringEncoder or StringDecoder as a type parameter as is appropriate. 
```
trait val StringEncoder
  fun encode(codepoint: U32): (USize, U8, U8, U8, U8)
  
trait val StringDecoder
  fun decode(bytes: U32): (U32, U8)
```

The ByteSeq type defined in std_stream.pony will be changed to remove String.
```
type ByteSeq is (Array[U8] val)
```
Many functions that accept ByteSeq as a parameter will be changed to accept (String | ByteSeq) as a parameter.

A new StringIter interface will be added to std_stream.pony
```
interface val StringIter
  """
  An iterable collection of String box.
  """
  fun values(): Iterator[this->String box]
```

Change Reader in buffered/reader.pony to add functions to read a codepoint and to read a String of a given number of codepoints. Update function line() to accept a decoder, and to return a pair with the line string, and the number of bytes consumed.

Change Writer in buffered/writer.pony to accept StringEncoder parameters in the write() and writev() functions. 

Add a FileCharacters class in files/file_characters.pony that provides an iterator of characters in a file. The implementation will be similar to the FileLines class in files/file_lines.pony.

Change character literals so that a character literal can only represent a single unicode codepoint. The following would be valid character literals:
```
let l1 = 'A'
let l2 = '🐎'
let l3 = '\x61' \\ only hex values up to 7F will be accepted.
let l4 = '\u20AC' \\ Unicode codepoint '€'
let l5 = '\U01F3A0 \\ Unicode codepoint '🎠'
```

Change the Pony tutorial to reflect the changes to the String class and character literals. Also state clearly that UTF-8 is the only valid encoding for Pony source code.

Not Supported:
1. lower() and upper() for unicode characters. Should remove lower_in_place() and upper_in_place() because these conversion are not safe.
1. The StdStream's (out, err, in) do not support specifying a character encoding. Ideally, the encoding for these streams would be set by the system at run-time based on the default encoding of the underlying system. For now, they will use utf-8 only.

# How We Teach This

This can be presented as a continuation of existing Pony patterns.

The Pony tutorial will need to be updated to reflect these changes.

# How We Test This

Extend CI coverage to cover these changes and new features.

# Drawbacks

This is a change to the String API, and as such will break existing programs. String functions returning or taking as parameters U8 values now returning or taking U32 values will probably be the most common source of program breakage. Also, programs that used the existing unicode friendly functions in String will need to change, but they should be greatly simplified.

# Alternatives

1. Leave the String class as it is. This is likely to result in hidden errors in many programs that work with Strings as they will not work correctly with unicode data if they encounter it. It will also make it difficult to use Pony in settings where ASCII is not sufficient for local language (most non English speaking countries).
1. A more complicated implementation with multiple String types capable of storing text data internally using different byte encodings. This approach would improve performance in situations where strings needed to be created from bytes of various encodings. The String type could be matched to the native byte encoding to eliminate any need for conversion. Such an implementation would add complexity to the String API as it would require use of a String trait with multiple implementations. It would also add considerable complexity to the String class implementation.
1. Add support for multiple String types, where only one could be active at a time in the Pony run-time. This would be easier to implement compared to multiple concurrent String types, and would add no complexity to the String API. It would improve performance in locales where non-ASCII characters are more prevalent such as Asia. 

# Unresolved questions

In lexer.cc I have incorporated a utf-8 decoding algorithm for character literals taken from https://bjoern.hoehrmann.de/utf-8/decoder/dfa/. Is this acceptable and how can credit be given?

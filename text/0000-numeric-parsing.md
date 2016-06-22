- Feature Name: number_parsing
- Start Date: 2016-06-21
- RFC PR:
- Pony Issue:


# Summary

Functionality for parsing numeric values from strings.


# Motivation

The proposed changes separate the functionality of numeric parsing and the
relevant error checking away from the built-in String class. Presently, integer
parsing with the `String.i8()` and similar methods throw an exception on many
cases of invalid input (like overflow or invalid characters), however floating
point parsing with `String.f32()` and similar do not have that capability.


# Detailed design


## Overview

A change to the `String.f32()` and `String.f64()` methods to have a return type of
`F32?` and `F64?` and adding a `String.read_float()` method with functionality
similar to `String.read_int()` would be sufficient basic number parsing.

It would also be beneficial to clarify the exact intent of the `String.i8()`
and `String.f32()` functions. One might define the intent of `String.i8()` to
be something akin to: parse any valid/in-bounds I8 literal defined in the
Pony language specification. This has the benefit of keeping parsing
semantically equivalent to the Pony language itself. As a consequence, the
`base: U8` argument should be removed from the methods.

An additional package with `IParse`, `UParse`, and `FParse` classes would
re-implement the lost flexibility from the previous changes and become the
go-to package for adding further parsing capabilities.


## Integers

Basic integer parsing could be done with a class having the following outline

```
class IParse[A: (I8 | I16 | ... )]
  // Exception if there is a no text, the text is not a valid integer, or it wont fit into A.
  fun from(text: String, offset: USize = 0, bounds: USize = 0): A?
  fun frombase(base: U8, text: String, offset: USize = 0, bounds: USize = 0): A?

  // Returns the parsed integer along with the number of characters used from the text.
  fun partiallyfrom(text: String, offset: USize = 0, bounds: USize = 0): (A, USize)
  fun partiallyfrombase(base: U8, text: String, offset: USize = 0, bounds: USize = 0): (A, USize)
```

Such a class is nice since the syntax is similar to English:

```
IParse[I32].from("554")
IParse[I64].frombase(16, "7FFF")
```

Objects of the `IParse` type would not be very useful so it would be nice to
provide an `IParser` class on which general parsing rules could be specified
and the `IParser.from` method would take the generic argument instead.

```
let iparse: IParser( /* maybe options */ )
iparse.from[I16]("554")
iparse.frombase[I16](16, "7FFF")
```

Potential options might include the ability to specify numeric delimiters and
other stylistic preferences.

The `UParse` and/or `UParser` could be encapsulated in the same class, as done
below in the following reference implementation for `UParse`.


```
// The Integer interface does include the checked operations, so do it here.
interface HasChecked[A: Integer[A] val]
  fun addc(y: A): (A, Bool)
  fun subc(y: A): (A, Bool)
  fun mulc(y: A): (A, Bool)

// Ideally, the checked operations will be integrated with the Integer type.
type IntegerExt[A: IntegerExt[A] val] is (HasChecked[A] & Integer[A])

// The parsing could be implemented many ways, but the functionality can
// probably be boiled down to calls of `partiallyfrombase`.
interface IParseCapable[A: ((Signed | Unsigned) & IntegerExt[A] val)]
  fun partiallyfrombase(
    base: U8,
    text: String,
    offset: USize = 0,
    boundary: USize = USize.max_value()
  ): (A, USize)

  fun partiallyfrom(
    text: String,
    offset: USize = 0,
    boundary: USize = USize.max_value()
  ): (A, USize) =>
    partiallyfrombase(10, text, offset, boundary)

  fun frombase(
    base: U8,
    text: String,
    offset: USize = 0,
    boundary: USize = USize.max_value()
  ): A? =>
    (let result: A, let used: USize) = partiallyfrombase(base, text, offset, boundary)
    if (used == 0) or (used != (boundary.min(text.size()) - offset)) then
      error
    end
    result

  fun from(
    text: String,
    offset: USize = 0,
    boundary: USize = USize.max_value()
  ): A? =>
    frombase(10, text, offset, boundary)

// This is a simple, potentially incomplete IParserCapable parser.
class IParse[A: ((Signed | Unsigned) & IntegerExt[A] val)] is IParseCapable[A]
  fun tag partiallyfrombase(
    base: U8,
    text: String,
    offset: USize = 0,
    boundary: USize = USize.max_value()
  ): (A, USize) =>
    if (base < 2) or (base > (10 + 26)) then
      return (0, 0)
    end

    var result: A = 0
    var index: USize = offset
    let usebase: A = A(0).from[U8](base)
    var negative: Bool = false
    var hasdigit: Bool = false
    var wasunderscore: Bool = false

    while (index < boundary) and (index < text.size()) do
      let char: U8 = try
          text(index)
        else
          0
        end

      if (char == '-') then
        if (index != offset) then
          return (0, 0)
        elseif (result.min_value() == 0) then
          return (0, 0)
        end
        negative = true
        wasunderscore = false
      elseif (char == '+') then
        if (index != offset) then
          return (0, 0)
        end
        wasunderscore = false
      elseif (char == '_') then
        if (not hasdigit) then
          return (0, 0)
        end
        wasunderscore = true
      else
        let code: A = if (char >= '0') and (char <= '9') then
            A(0).from[U8](char - '0')
          elseif (char >= 'A') and (char <= 'Z') then
            A(0).from[U8]((char - 'A') + 10)
          elseif (char >= 'a') and (char <= 'z') then
            A(0).from[U8]((char - 'a') + 10)
          else
            A(0).from[I8](I8.max_value())
          end

        if code.u8() >= base then
          return (0, 0)
        end

        hasdigit = true

        (let r: A, let o: Bool) = result.mulc(usebase)
        (let r': A, let o': Bool) = if negative then
            r.subc(code)
          else
            r.addc(code)
          end

        if o or o' then
          break
        end
        
        wasunderscore = false
        result = r'
      end

      index = index + 1
    end

    if (not hasdigit) or wasunderscore then
      return (0, 0)
    end

    (result, index - offset)

// Some quick tests.
actor Main
  let _env: Env

  new create(env: Env) =>
    _env = env

    testI8("-128")
    testI8("-127")
    testI8("-55")
    testI8("-9")
    testI8("")
    testI8("-")
    testI8("-+")
    testI8("-1")
    testI8("--1")
    testI8("0")
    testI8("+")
    testI8("55")
    testI8("5_5")
    testI8("_55")
    testI8("55_")
    testI8("55_5")
    testI8("127")
    testI8("128")
    testI8("1270")
    testI8("1280")
    
  fun testI8(text: String) =>
    (let v, let u) = IParse[I8].partiallyfrom(text)
    _env.out.print("IParse[I8].from(\"" + text + "\") = " +
      "(" + v.string() + ", " + u.string() + ") -> " +
      try
        IParse[I8].from(text).string()
      else
        "error"
      end
    )
```

## Floating Point

By and large, the functionality of an `FParse` class would be very similar to
`IParse` or `UParse`, however some subtle differences may occur. Consider the
outline for the class:

```
class FParse[A: (F32 | F64 | ...)]
  fun from(text: String, offset: USize = 0, bounds: USize = 0): A?
  fun partiallyfrom(text: String, offset: USize = 0, bounds: USize = 0): (A, USize)
```

A typical usage would look like

```
FParse[F64].from("10.0")
```

However, unlike `IParse` there would not be an inherent limit to the number
of characters that would be parsed and there is no limit to how small of
a number you can represent in a string, so the following returns values
as close as possible to the provided string, but do not fail

```
FParse[F64].from("10.000000000000000000000000000000000000000000000000001")
FParse[F64].from("1e-100000")
```

On the other hand, the following numbers would not fit in a `F64` variable,
so an error would be produced:

```
FParse[F64].from("1e100000")
```

The `FParse.partiallyfrom` would return the portion of the parsed number and
the number of characters used from the string.

```
FParse[F64].partiallyfrom("1.1")
FParse[F64].partiallyfrom("1.1asdf")
```

Both return about `(1.1, 3)`.


# How We Teach This

The usage of `IParse`, `UParse`, and `FParse` would fit well in a guide (or
section of a guide) covering how to process data from files or standard input.

The terms for parsing fit well with the proposed functionality, but the term
serialization may also fit. 


# Drawbacks

For existing Pony users, usage of the proposed `String.f32()` and  `String.f64()`
methods could break previously compiling code, since they will now throw
exceptions. Also, usage of any of the `String.i8()` or similar with the `base`
argument supplied will no longer compile.


# Alternatives

It may make sense to add a `valueof(literal: String): A?` function to each of the
I8, F32, and other primitive types, similar to `toString()` and `valueOf(String)`
from Java, which seems to work well.


# Unresolved questions

How SHOULD the existing `String.f32()` and `String.i8()` functions behave (what is
their intent)?

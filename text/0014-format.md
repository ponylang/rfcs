- Feature Name: format
- Start Date: 2016-07-27
- RFC PR: 
- Pony Issue: https://github.com/ponylang/ponyc/issues/1285

# Summary

This RFC proposes the seperation of the `string()` method and formatting. This wil remove formatting from the builtin package of the standard library and seperate the disperate concerns of producing a string representation of an object and formatting strings.

# Motivation

The seperation of string formatting will allow packages to implement string formatting that may not be relevant to general formatting. This may enclude date and time formatting or JSON pretty printing. Pony's string formatting should also have improved documentation since it differs from that of most other languages.

# Detailed design

- Redefine the Stringable interface:
```pony
interface box Stringable
  """
  Things that can be turned into a String.
  """
  fun string(): String iso^
    """
    Generate a string representation of this object.
    """
```
- Modify all classes that currently implement the Stringable interface to reflect the new interface
- Allow numbers to keep implementing the interface by modifying the `_ToString` primitive in builtin to create strings in base 10 only.
- Create a package `format` that includes a `Format` primitive with the following methods:
```pony
primitive Format
  """
  Provides functions for generating formatted strings.

  * fmt. Format to use.
  * prefix. Prefix to use.
  * prec. Precision to use. The exact meaning of this depends on the type,
  but is generally the number of characters used for all, or part, of the
  string. A value of -1 indicates that the default for the type should be
  used.
  * width. The minimum number of characters that will be in the produced
  string. If necessary the string will be padded with the fill character to
  make it long enough.
  *align. Specify whether fill characters should be added at the beginning or
  end of the generated string, or both.
  *fill: The character to pad a string with if is is shorter than width.
  """
  fun apply(str: String, fmt: FormatDefault = FormatDefault,
    prefix: PrefixDefault = PrefixDefault, prec: USize = -1, width: USize = 0,
    align: Align = AlignLeft, fill: U32 = ' '
  ): String iso^ =>

  fun int[A: (Int & Integer[A])](x: A, fmt: FormatInt = FormatDefault,
    prefix: PrefixNumber = PrefixDefault, prec: USize = -1, width: USize = 0,
    align: Align = AlignRight, fill: U32 = ' '
  ): String iso^ =>

  fun float[A: (Float & FloatingPoint[A])](x: A,
    fmt: FormatFloat = FormatDefault,
    prefix: PrefixNumber = PrefixDefault, prec: USize = 6, width: USize = 0,
    align: Align = AlignRight, fill: U32 = ' '
  ): String iso^ =>

```
- The following standard library packages need minor updates: crypto, json, net/http, serialize, and strings

Example use of `Format`:
```pony
Format.int[U32](3, FormatDefault, PrefixDefault, 3, 5))
// => "  003"
```

# How We Teach This

Formatting will not change, but the way that it is applied to strings will. Explanations and examples will be given in both the package documentation and in the Pony tutorial.

# Drawbacks

- Exisiting code will be broken

# Alternatives

- Not to do this

# Unresolved questions

None

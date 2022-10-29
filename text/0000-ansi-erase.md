- Feature Name: Add erase codes to term package
- Start Date: 2022-10-26
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Add erase left and erase line codes to the term package.

# Motivation

We currently support "erase to the right" but not "erase to the left" and
"erase the entire line". Given these are all "erase" functions and we already
have an `erase` method on the `Ansi` primitive in the term package it was
decided that we needed an RFC before adding them as there are multiple ways
to go about adding them.

# Detailed design

Three new public primitives will be created in the `term` package that will be
used to control which direction `erase` erases aka, what code it will return.

```pony
primitive EraseLeft
primitive EraseLine
primitive EraseRight

type _EraseDirection is (EraseLeft | EraseLine | EraseRight)
```

And erase will be updated accordingly:

```pony
  fun erase(direction: _EraseDirection = EraseRight): String =>
    """
    Erases content. The direction to erase is dictated by the `direction`
    parameter. Use `EraseLeft` to erase everything from the cursor to the
    beginning of the line. Use `EraseLine` to erase the entire line. Use
    `EraseRight` to erase everything from the cursor to the end of the line.
    The default direction is `EraseRight`.
    """
    match direction
    | EraseRight => "\x1B[0K"
    | EraseLeft => "\x1B[1K"
    | EraseLine => "\x1B[2K"
    end
```

# How We Teach This

The only teaching will be in the method documentation for `erase` on the `Ansi`
primitive. The current documentation will be updated to reflect the changes
detailed in this RFC.

# How We Test This

Just about every approach we as an option is a very simple implementation where
unit tests wouldn't add any additional value. No new tests will be added. No
existing tests will be updated.

# Drawbacks

Given that the Ansi primitive is incomplete and that we have stated previously
that we are open to making the change, I don't believe there are any real
drawbacks. We should certainly do something to add the additional methods.

The suggested approach adds 3 primitive to the `term` package that will be
additional symbols in the `term` package so if someone is importing the symbols
from term into their own module, then it is possible that a collision will
occur so this is technically a breaking change.

# Alternatives

Other options:

Have `erase_left`, `erase_line`, `erase_right` methods on `Ansi`. This would
be a breaking change as we would be removing the `erase` method.

Have `erase_left`, `erase_line`, `erase` methods on `Ansi`. This leaves the
existing `erase` method in place and doesn't add an `erase_right` method. This is a non-breaking change but makes for an API that would be surprising.

# Unresolved questions

There's no unresolved questions that I am aware of.

- Feature Name: add_ansi_escape_codes
- Start Date: 2022-02-14
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

This RFC proposes the addition of more escape code functions to the ANSI
primitive of the term package.

# Motivation

The purpose of these additional methods is to cover more of the standard ANSI
escape codes within the stdlib.

# Detailed design

## Added Escape Codes

- 8-bit foreground `\x1B[38;5;nm` and background `\x1B[48;5;nm` colors
- 24-bit foreground `\x1B[38;2;r;g;bm` and background `\x1B[48;2;r;g;bm` colors
- enter alternate screen buffer `\x1B[?1049h` and leave alternate screen buffer `\x1B[?1049l`
- bell alert `\x7`
- scroll up `\x1B[nS` and scroll down `\x1B[nT`
- next line `\x1B[nE` and previous line `\x1B[nF`
- cursor horizontal absolute `\x1B[nG`
- hide cursor `\x1B[?25l` and show cursor `\x1B[?25h`
- save cursor position `\x1B[s` and restore cursor position `\x1B[u`
- device status report `\x1B[6n` (sends cursor position to stdin)
- faint `\x1B[2m`, italic `\x1B[3m`, conceal `\x1B[8m`, and strike `\x1B[9m` text
- erase in display `\x1B[nJ`
- erase in line  `\x1B[nK`


## Erase In Display/Line

There are currently two similar functions, but they have a couple of issues:
- Neither of them expose the parameter that the escape codes take.  
- The `clear` function moves the cursor to the top left and then clears the screen.  
This may have been done to create the same result that this escape code gave on DOS.

Unlike the other added escape codes, these two only have a few valid values
for the parameters.  
To enforce the safety of these functions using the type system, four primitives
and two type unions would be defined to be used as the parameters for these
two functions.

```pony
primitive EraseAfter
primitive EraseBefore
primitive EraseAll
primitive EraseBuffer

type EraseDisplay is (EraseAfter | EraseBefore | EraseAll | EraseBuffer)
type EraseLine is (EraseAfter | EraseBefore | EraseAll)
```


# How We Teach This

The added functions would be documented as the existing functions on the `ANSI`
primitive are and an example of usage would be added to `ANSI`.

# How We Test This

The functions that have parameters would have tests added to ensure that they
return the correct escape code for the given parameters.

The functions that would have parameters and would be tested are:
- 8-bit and 24-bit colors for the foreground and background
- scroll up and scroll down
- next line and previous line
- cursor horizontal absolute
- erase_display
- erase_line

# Drawbacks

Some escape codes may not work on all terminals.

# Alternatives

Don't add these escape code functions and have users look up and print the
escape codes they want.

# Unresolved questions

None

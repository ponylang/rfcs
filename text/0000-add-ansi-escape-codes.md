- Feature Name: add_ansi_escape_codes
- Start Date: 2022-02-14
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

This RFC proposes the addition of more escape code functions to the ANSI primitive of the term package and the consolodation of the thirty-two existing color functions into four functions.

# Motivation

The purpose of these additional methods is to cover more of the standard ANSI escape codes within the stdlib.

# Detailed design

- Add escape codes for 3-bit, 4-bit, 8-bit, and 24-bit colors for the foreground and background.  
The naming scheme of the color functions would be `{fg,bg}_{3,4,8,24}bit`.  
The 3-bit, 4-bit, and 8-bit versions would take a U8 specifying the color.  
The 24-bit versions would take three U8s specifying the r, g, and b values.  
- Remove the thirty-two named color functions in favor of the 3-bit and 4-bit functions.
- Add escape codes for enter and leave alternate screen buffer.
- Add escape code for the bell alert.
- Change `clear` and `erase` functions to take a U8 specifying what part of the screen/line to clear.  
The default for the escape codes if a value isn't given is zero.  
The action these functions currently take is three for `clear` and one for `erase`.  
I would like to have the default value in these functions be zero.
- Add escape codes for scroll up/down.
- Add escape codes for next/previous line.
- Add escape code for cursor horizontal position (moves the cursor to column n in the current line).
- Add escape codes for hide/show cursor.

If a value passed to any of the functions is invalid, such as 200 being passed to `fg_3bit`, an empty string would be returned.

# How We Teach This

The added functions would be documented as the existing functions on the `ANSI` primitive are and an example of usage would be added to `ANSI`.

# How We Test This

I could not find existing testing for the `ANSI` primitive.  
If there are existing tests for these functions, additional tests in the same format would be added to ensure that the new functions return the correct escape codes.  
Most of these functions are just directly returning a string of the escape code without any parameters so they're pretty straightforward.

# Drawbacks

The removal of the existing color functions and the change to the `clear` and `erase` functions (if the default of zero is used) are breaking changes.

# Alternatives

## Alternative to the rfc as a whole
These escape codes can simply be printed independently of whatever is supported by functions on `ANSI`.  
Having them available on `ANSI` simply makes it so that users do not need to look the codes up themselves.

## Alternative to the breaking changes
The existing color functions could remain and the 3-bit and 4-bit color functions could exist alongside them or not be implemented.  
The `clear` and `erase` functions could have default values that match their existing behavior.

# Unresolved questions

Should the breaking changes be made to simplify the interface?

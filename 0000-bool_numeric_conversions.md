- Feature Name: bool_numeric_conversions
- Start Date: 2016-10-24
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Allow conversion between Bool and numeric types, and vice-versa, and allow
buffered Reader/Writer to read/write bools as their underlying I8
representation.

# Motivation

It is common in other languages to sometime want to represent the value of a
Bool numerically. In Pony, for example, when writing to a buffered Reader/Writer,
it is currently necessary to use comparions and if clauses to write a Bool. In
some cases this leads to additional inefficiencies, and can be viewed as "not
very elegant". 

# Detailed design

The basic idea is to allow access to the underlying I8 representation of Bool
and enable conversion between that I8 and other numeric types. This would mean
adding the .u8(),.u16(), etc conversion functions on Bool and .bool() functions
on the numeric types.

The numeric equivalence should be 0 for false, and 1 for true. Other numeric
values could be "undetermined behaviour" (especially negative numbers), however
it is generally understood that positive numbers are usually interpreted as true.

It is open to interpretation as to what the semantic meaning (other than for
convenience) of converting between Bool and numeric types might be (e.g. is
7 true? if so, why?).
However, this is a problem common to most languages, and the fact that the
conversion would always be explicit by the means of calling the relative
conversion function would mean that the programmer would have to at least
thought about the current thing they are trying to achieve.

This is especially true when thinking about floating point numbers. Looking at
the way this would be implemented, the f64(), f128() etc functions would be
added "for free", but we may want to decide to "hide them", so that conversion
between Bool and floating point is never possible. 

The Reader and Writer from the buffered package will also have the respective
bool() functions that write the underlying numeric I8 to the buffer. This saves
unnecessary comparisons and other artefacts.

# How We Teach This

Updating the documentation for the standard library, and adding notes that the
conversion only guarantees that 0 = false and 1 = true, and all other behaviour
is undefined.

This does not change how Pony is taught and does not affect the guides.

By making it available in the documentation.

# How We Test This

A simple unit test to ensure that the base cases work as expected might be
sufficient. And, round-tripping a boolean through a numeric representation
should always give back the same boolean value (e.g. false => 0 => false).

# Drawbacks

Developers may introduce subtle bugs in their Pony programs if they use this
feature in the wrong way. E.g. by relying on the fact that 3.576 = true.

# Alternatives

* Leaving things as they are. This, for example, means that to write a Bool to a
buffer it is necessary to use an if statement to make a u8 to be written, and
then to read it it will be necessary to read a u8 and make a comparison.

* Only allow conversion between bool and U8 / I8. However, given that U8 / I8
can be converted to any other numeric type, this still opens up the same
semantic issues. It makes them a little bit more explicit by having two chained
calls though. E.g. boolvalue.u8().f64() or number.u8().bool().

# Unresolved questions

Is there any point in allowing conversion between Bool and floating point?

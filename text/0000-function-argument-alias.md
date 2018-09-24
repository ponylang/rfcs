- Feature Name: Function argument alias
- Start Date: 2018-09-24
- RFC PR:
- Pony Issue:

# Summary

Pony's shadowing prohibition means that using an object field or
method name as a function argument is not allowed. This is a
proposal to add an optional clause to function arguments that gives
the argument a local alias.

# Motivation

Function arguments are part of the public API of a class. They appear
in the documentation, in error messages and are used explicitly when
calling a function using named arguments.

In a variety of situations, a function argument will naturally
correspond to a class field or method, for example when a constructor
provides a way to directly pass an initial state, or when a method
replaces a field with a new value. For ergonomics and ease of use,
it's ideal to be able to use the most simple and obvious argument name
here. That is, if a method updates the field `_name` then the most
obvious argument for that method is `name`.

However, if we want to allow public access to that field then we're
out of luck due to the shadowing prohibition. The only solution in
this case is to use a different name for the function argument such as
`new_name`, `_name` or `name'`, not of which are ideal.

This problem applies for any function, whether it's a constructor or a
method. It's been brought up occassionally on the mailing list with
Joe McIlvain suggesting a change such that an argument `name'` could
be filled with the named argument `name` (provided that no parameter
is using the "unprimed" name). This solution does not seem to solve
the problem of primed arguments appearing in error messages and
documentation. And it could be argued that it makes the language
harder to understand.

# Detailed design

The design has been borrowed from OCaml and is perhaps the most
straight-forward solution:
```pony
class Thing
  let name: String
  let cost: I64

  new create(name: String = "" as name', cost: I64 = 0 as cost') =>
    name = name'
    cost = cost'
```
That is, after a function argument, we allow an optional "as" clause such that the argument is available locally under a different name.

Of course, the shadowing prohibition applies for the new name and the
name must not be used by other arguments.

# How We Teach This

The "Shadowing" section in the tutorial needs to be updated:

> If you need a variable with nearly the same name, you can use a prime '.

This would be changed to:

> If you need a variable with nearly the same name, you can use a
> prime ' or use a local alias for the variable using the `as`
> keyword.

An example should follow or a link to the "Classes" section.

The Wombat example in the "Classes" should be updated to reflect this
language change:
```pony
class Wombat
  let name: String
  var _hunger_level: U64

  new create(name: String as name') =>
    name = name'
    _hunger_level = 0

  new hungry(name: String as name', hunger_level: U64) =>
    name = name'
    _hunger_level = hunger_level
```

# How We Test This

The new syntax is fully backwards compatible so we only need to test
the new functionality.

# Drawbacks

This proposal uses the `as` keyword which is already use to convert a
value to another type.

# Alternatives

Two alternatives that have been brought up previously, the first being
the suggestion to allow the use of a non-primed named argument as
already presented, the other being using a special marker for
constructor arguments that should always be set directly on the
created object.

This latter approach is used by for example TypeScript where you can
put either `public` or `private` in front of an argument and have it
automatically defined and set on the class.

However, this does not solve the more general problem which applies to
all functions and in which we don't always simply want to assign the
argument as the value for the corresponding field. An example might be
a date object where we both want to be able to pass arguments for day,
month and year as part of the construction and be able to use the same
names for methods such as `day()`, `month()` and `year()`.

# Unresolved questions

None.

- Feature Name: type_case_in_match_expression
- Start Date: 2016-08-02
- RFC PR:
- Pony Issue:

# Summary

This RFC defines a syntax for `match` expressions that allows a developer to define a case as a "type case". A type case is one where a value comparison is not desired and a variable assignment is not needed. The logic used in determining a matching type is the same as that of the `as` operator.

# Motivation

There are cases where the primary desire of a `match` case is only to disambiguate its type. In some cases, a developer may wish to work with the disambiguated value, while in other cases the value itself may be irrelevant.

Currently, in order to match only on type, a variable must be declared in the case expression in order to indicate a type match, even if a variable isn't needed. This is more verbose and less clear than it could be.

Additionally, the current syntax that matches on *value* can easily be mistaken for a type comparison. With a `| MyType =>` case, it's easy to forget that if `MyType` is a `class`, then it is expected to have a no-param constructor and an `eq()` method. A dedicated syntax for matching on type should help in this regard.

So the type case syntax will allow a more clear and clean interface to what is ultimately the intent of the case. That improved syntax is the primary motivation of this RFC, and was raised as a concern in [issue #876](https://github.com/ponylang/ponyc/issues/876).

It seems there may also be *potential* to simplify management of *reference capabilities* in some cases. *(See 'Unresolved questions' below.)*

# Detailed design

The proposed syntax is to simply allow a `match` case to be defined as the keyword `as` followed by the name of a type and an optional *reference capability* annotation. If no *rcap* annotation is provided, the default for that type is used. As expected, the *rcap* of the type must be a valid subtype of the original.

If the type case matches the subject of the `match`, the branch for that match is then entered just like any other case, except that if the subject of the match was a field or variable, then that field or variable could be directly used as the matched type.

As a simple example, if we have a field `n` in a `box` method that is a `(USize | String ref)`, we currently may do something like this:

``` pony
let m = match n
| let us: USize => us
| let str: String box =>
  try str.usize()
  else USize(0)
  end
end
```

This is simple enough, though it's less clean than it could be. Ultimately the variables are there only to facilitate working with a variable that we could potentially work with directly.

Given this RFC, we could update the above code to this:

``` pony
let m = match n
| as USize => n
| as String box =>
  try n.usize()
  else USize(0)
  end
end
```

Even in this simple example, the syntax is shorter and cleaner, it's clear that we're specifically interested in `n as USize` or `n as String box`, and the need for the ancillary variable has been eliminated.

Type cases would be able to be mixed with the current case definitions available in `match` expressions. Nothing really changes in this regard. While there could be concern that a developer may define cases that wholly overlap, in reality they can do that with the current syntax.

For example, this:

``` pony
match "foo"
| let str: String => str
| as String => "default" // Will never be matched
end
```

...can today be written as this:

``` pony
match "foo"
| let s: String => s
| let s: String => "default" // Will never be matched
end
```

If these impossible-to-reach cases are addressed in the future, they would be addressed for both syntax.

There should be no surprises with respect to guard expressions, though it should be noted that the original field or variable would, as likely expected, be available to be used as the matched type in the guard, just as it's able in the branch.

``` pony
let m = match n
| as USize if n < 10000 => n
| as String box if n.size() < 5 =>
  try n.usize()
  else USize(0)
  end
else USize(0)
end
```

The `as` keyword is currently used as an infix operator, and it is also used in a manner somewhat similar to this RFC as the type designator of an Array literal. In both cases, a type is expected to follow `as`, so this new use of `as` fits in comfortably.

# How We Teach This

The term "type case" is a possible term for this feature because it succinctly describes precisely what it is... a match case that matches solely on the value's type.

This syntax would be taught in the current [Match Expressions](http://tutorial.ponylang.org/pattern-matching/match.html) page of the tutorial. Currently there is a section on *"Captures"*, which describes the practice of declaring a variable in the case expression, to which the value is assigned upon successful match. I believe that section should come after the one that describes this new behavior, as I think this syntax is a little simpler, and provides an easy pathway to describing the "captures" syntax.

I think this syntax should favored for the general case where a field or variable currently exists, or the value simply isn't used in the branch, and the "captures" syntax should be favored for the case where there is no current reference, such as the result of a function call, assuming a variable reference is actually needed:

``` pony
let m = match _get_numeric_value()
| let n: USize if n < 10000 => n
| let n: String box if n.size() < 5 =>
  try n.usize()
  else USize(0)
  end
else USize(0)
end
```

Overall, I don't think this adds any significant complexity to the language or cognitive burden to the developer, and should be fairly easily taught.

# Drawbacks

As always, a new syntax adds one more thing to learn, and as such, any new feature must justify its existence. The greater the cognitive burden, the greater the burden of justification.

This could be seen as making *"two ways to accomplish the same thing"*.

# Alternatives

Not implementing this syntax is an alternative.

Creating a separate kind of expression that only matches on type is another alternative. This would be akin to Go's *type switch* statement, though I don't think that's as desirable as this.

If this is not implemented, we will continue to use an ancillary variable to match by type.

# Unresolved questions

Does this conflict in any way with *case functions*?

Should the syntax be extended to matching on tuples, such as `| (as String, 3) => " three"`?

Would this syntax potentially give us the ability to use an `iso` reference in a `match` without needing to consume it, assuming all the cases of the `match` were type cases?

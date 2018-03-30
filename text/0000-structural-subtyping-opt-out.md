- Feature Name: structural-subtyping-opt-out
- Start Date: 2018-03-30
- RFC PR:
- Pony Issue:

# Summary

Add an annotation specifying that a given type shouldn't be a structural subtype of any other type.

# Motivation

We will illustrate the goal of this RFC with an example.

```pony
class Empty

class Foo
  fun foo[A: Any](a: (A | Empty val)) =>
    match consume a
    | let a': A => None
    end
```

This currently causes a compiler error because `Empty` is part of the constraint of `A` (`Any #any`). An example of a problematic reification would be `foo[Empty ref]`. Here, the type of the match operand would be `(Empty ref | Empty val)`, which means that this would be an unsafe match, as capabilities can't be differentiated at runtime. Similar cases have been reported, see for example [ponyc/#2584](https://github.com/ponylang/ponyc/2584) and [ponyc/#2182](https://github.com/ponylang/ponyc/2182).

This RFC proposes a simple way to specify that `Empty` shouldn't be a subtype of `Any`. This new functionality should solve the most common and straightforward cases of this problem. Other cases (for example with multiple type parameters that should be disjoint) will be covered in a future, more complex RFC.

# Detailed design

A new annotation, `nostructural`, will be introduced. This annotation is recognised on any non-anonymous type definition, except for type aliases. A type annotated with `nostructural` will not be a subtype of any interface, even if the type provides every method required by the interface. In addition, if a `nostructural` type has an interface (not a trait) in its provides list, a compilation error will be reported.

The example above can be fixed by annotating `Empty` with `nostructural`. That way, `Empty` isn't a subtype of `Any`, which means that `A` and `Empty val` are guaranteed to be disjoint. This also means that `Empty` cannot be used as a type argument to `foo`.

# How We Teach This

The annotation will be described in the annotations section of the tutorial. In addition, it could be the subject of a pony pattern.

# How We Test This

We would test that a `nostructural` type isn't a subtype of an interface that it would provide if it weren't `nostructural`.

# Drawbacks

The drawbacks of this change would be very limited since it wouldn't break any existing code, and the implementation would be a small new check in the subtype checking code.

# Alternatives

The future RFC mentioned earlier (which consists of a relative complement type operator) would cover most of the use cases covered by this RFC, but still has some limitations which are resolved by `nostructural`. This RFC is a complement rather than an alternative.

Possible syntactic alternatives for opting a type out of structural subtyping would be a keyword or symbol instead of an annotation, or a completely new kind of nominal types.

Regardless of the syntactic form, the author of this RFC believes that this functionality is necessary for the flexibility of the type system when handling generic constraints.

# Unresolved questions

None.

- Feature Name: subtyping-exclusion
- Start Date: 2018-03-30
- RFC PR:
- Pony Issue:

# Summary

Add an annotation specifying that a given type shouldn't be a subtype of any other type.

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

This currently causes a compiler error because `Empty` is part of the constraint of `A` (`Any #any`). An example of a problematic reification would be `foo[Empty ref]`. Here, the type of the match operand would be `(Empty ref | Empty val)`, which means that this would be an unsafe match, as capabilities can't be differentiated at runtime. Similar cases have been reported, see for example [ponyc/#2584](https://github.com/ponylang/ponyc/issues/2584) and [ponyc/#2182](https://github.com/ponylang/ponyc/issues/2182).

This RFC proposes a simple way to specify that `Empty` shouldn't be a subtype of `Any`. This new functionality should solve the most common and straightforward cases of this problem. Other cases (for example with multiple type parameters that should be disjoint) will be covered in a future, more complex RFC, which we'll describe summarily here in order to give some context on the relation between these two RFCs.

## Companion RFC: the relative complement type operator

This other RFC will introduce a new type operator: the relative complement, which is written `(A \ B)`. Here, the type `(A \ B)` is every type that is both a subtype of `A` and not a subtype of `B`.

The example above can be solved with this functionality by setting the type parameter constraint to `(Any \ Empty)`. However, this causes a usability problem if we want to reify `foo` with `Any`: since `Any` doesn't fulfil the constraint `(Any \ Empty)`, the type argument must also exclude `Empty`, resulting in the reification being `foo[(Any \ Empty)]`. This is even more problematic if `Empty` were a private type, since it wouldn't be referenceable from other packages, a type argument of `(Any \ _Empty)` would be impracticable.

For this reason, the author of this RFC believes that both RFCs are necessary in order to fully solve the problem at hand.

# Detailed design

A new annotation, `nosupertype`, will be introduced. This annotation is recognised on any non-anonymous type definition, except for type aliases. A type annotated with `nosupertype` will not be a subtype of any other type (except `_`), even if the type structurally provides an interface. If a `nosupertype` type has a provides list, a compiler error is reported. As a result, a `nosupertype` type is excluded from both nominal and structural subtyping.

The example above can be fixed by annotating `Empty` with `nosupertype`. That way, `Empty` isn't a subtype of `Any`, which means that `A` and `Empty val` are guaranteed to be disjoint. This also means that `Empty` cannot be used as a type argument to `foo`.

# How We Teach This

The annotation will be described in the annotations section of the tutorial. In addition, it could be the subject of a pony pattern.

# How We Test This

We would test that a `nosupertype` type isn't a subtype of a type that it would be a subtype of if it weren't `nosupertype`.

# Drawbacks

The drawbacks of this change would be very limited since it wouldn't break any existing code, and the implementation would be a small new check in the subtype checking code.

# Alternatives

As explained earlier, the companion RFC would cover most of the use cases covered by this RFC, but still has some limitations which are resolved by `nosupertype`. This RFC is a complement rather than an alternative.

Possible syntactic alternatives for excluding a type from subtyping would be a keyword or symbol instead of an annotation, or a completely new kind of nominal types.

Regardless of the syntactic form, the author of this RFC believes that this functionality is necessary for the flexibility of the type system when handling generic constraints.

# Unresolved questions

None.

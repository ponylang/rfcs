- Feature Name: subtype-checking
- Start Date: 2016-10-23
- RFC PR:
- Pony Issue:

# Summary

Add a language construct allowing programmers to get information on subtyping relationships. This construct could be used in conditionals to conditionally compile code, or in method signatures to conditionally compile a whole method.

# Motivation

There are two main areas that can be improved by this feature.

First, there are a lot of cases where it would be useful to have a method on some reified versions of a generic type, but not in the general case. For example, a `string()` method could be added to the `Array[A]` class in the standard library when `A` is a subtype of `String`.

Second, this can greatly help performance. Currently, the only way to "specialise" an implementation for a specific subtype is to use pattern matching on an interface (see `String.append` for an example). This has a runtime cost, which wouldn't exist in a compile-time specialisation. Combined with type parameter inference, it could be a nice way to provide user-friendly static dispatch in the language.

# Detailed design

The core idea is to add a new "is subtype" binary operator, working on types at compile-time. The expression `A <: B`, with `A` a generic type and `B` an arbitrary type (including complex types) would return true if `A` is a subtype of `B` and `false` otherwise. If the result of the expression is true, `A` becomes constrained to `B` (i.e. as if declared as `[A: B]`) for the rest of the current block of code. Since that last property can dramatically change the code that must be generated, the `<:` operator is only allowed in two specific cases, detailed later in the RFC.

`A` can also be a tuple of generic types to allow checking multiple types at the same time, e.g. `(A1, A2) <: (B1, B2)`. In that case, `A1` becomes constrained to `B1` and `A2` becomes constrained to `B2`.

If it can be proven that `A <: B` is always false (`B` isn't a subtype of the existing constraint of `A`), a compilation error is issued. Since type checking occurs before reification and `B` can't be generic, the programmer can always fix the problem.

## The `iftype` conditional

The syntax of this new conditional is

```pony
iftype A <: B then
  // Generate this block if A is a subtype of B.
  // A is constrained to B in this block.
else
  // Generate this block otherwise
end
```

The single keyword `iftype` is proposed for consistency with the `ifdef` keyword. The only syntax element allowed in an `iftype ... then` is a single occurrence of the `<:` operator with valid types in both the left and right-hand side. Since `B` can be a complex type, it is possible to check for subtyping relationships involving more than two types (e.g `(A <: B) and (A <: C)` is equivalent to `A <: (B & C)`).

## Specialised generic functions

These function signatures are syntactically similar to case functions. A function without an `iftype` guard is called a default function and a function with an `iftype` guard is called a specialisation.

```pony
fun foo(x: A): B => // Default function. Optional.
fun foo(x: A): B iftype A <: B => // A is constrained to B in this specialisation.
```

If the subtyping relationship isn't verified, the default function is used. If there is no default function, the function is completely removed from the associated type. Since `A` must be a generic parameter, functions would only be conditionally removed from specific reifications of generic types. This wouldn't impair type checking.

If multiple specialisations of the same function are supplied with different subtyping constraints, the specialisation with the matching relationship is selected. If multiple specialisations match, and the constraint of one of them isn't a subtype of the constraint of the other, the specialisation is considered ambiguous and a compilation error is issued. If there is a subtyping relationship between the matching specialisations, the subtype is selected.

The type of every specialisation of a function must be a subtype of the type of the default function. If the constraint of a specialisation is a subtype of the constraint of another specialisation, the function type of the subtyped specialisation must also be a subtype of the function type of the supertyped specialisation. This is safe because for any given reification of the function, the most specific subtype is selected if there is a subtyping relationship between constraints.

### Relationship with case functions

These new specialised functions are a new layer on top of case functions and do not interfer with them. Case functions would be considered in the same set only if their subtyping constraint is the same (i.e. they're in the same specialisation). As with non-case functions, only one set of specialised case functions would be selected and compiled in the type. The proposed syntax for a specialised case function with a guard is

```pony
fun foo(x: A): B iftype A <: B and if x > 5 =>
```

The `and` isn't required for parsing and is only added for clarity for human readers.

# How We Teach This

This feature uses two complex elements of the language, generics and subtyping. A detailed explanation in the Generics chapter of the tutorial would be required.

# How We Test This

We already have extensive unit testing for subtyping. The only new testing needed would be to ensure that the correct code is generated for both the conditional and the function specialisations. Manually verifying by looking at the actual generated code seems required here.

# Drawbacks

Possible implementations are probably non-trivial. While it shouldn't break existing code since that new feature is relatively isolated, it would certainly add some maintenance cost.

# Alternatives

Use pattern matching on interfaces, as described in Motivation. This is bad for performance and can result in superfluous error handling (e.g. in a function where an error is raised if a type doesn't match a constraint that could be checked at compile-time with the feature proposed here).

# Unresolved questions

None.

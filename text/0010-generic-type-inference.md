- Feature Name: generic-type-inference
- Start Date: 2016-08-11
- RFC PR: https://github.com/ponylang/rfcs/pull/26
- Pony Issue: https://github.com/ponylang/ponyc/issues/1184

# Summary

Add type parameter inference for generic types and generic functions based on the existing inference rules for local variables.

# Motivation

Programmers are lazy and typing type arguments is a lot of work. A smart compiler should infer type parameters when possible.

# Detailed design

The design proposed here uses the existing type inference rules. The usage of these rules in this new context will be illustrated with examples. The proposal covers generic functions with inference through function parameters and generic types with inference through constructor parameters.

- Types are inferred from function arguments, only if the generic type appears in the function parameters.
  - `fun foo[A](a: A)`: `A` can be inferred.
    - `foo("str")`: `A` is inferred as `String`.
    - `foo(String)`: `A` is inferred as `String ref`.
  - `fun foo[A](a: String)`: `A` cannot be inferred.
  - `fun foo[A](a: Array[A])`: `A` can be inferred.
    - `foo(Array[U8])`: `A` is inferred as `U8`.
- If the type parameter has a default type, the inferred type is first matched against that type. If the inferred type is a subtype of the default type then the final deduced type is the default type and if it isn't the final type is the inferred type.
  - `fun foo[A: Any = Stringable](a: A)`
    - `foo(String)`: `String ref` is a subtype of `Stringable`, `A` is inferred as `Stringable`.
    - `foo(Array[U8])`: `Array[U8]` isn't a subtype of `Stringable`, `A` is inferred as `Array[U8]`.
  - `fun foo[A: Any = Stringable](a: Array[A])`: Even if a given type `A` is a subtype of another type `B`, the type `C[A]` is never a subtype of `C[B]`. Therefore, if the type parameter is used as a generic argument in the type of a function parameter, the default type parameter is ignored.
    - `foo(Array[U8])`: `A` is inferred as `U8` even though `U8` is a subtype of `Stringable`.
- When multiple function parameters use the same type parameter, the inferred types must either be the same or have a subtyping relationship between each other. In that case the final inferred type is the supertype.
  - `fun foo[A](a1: A, a2: A)`
    - `foo(String, None)`: Won't compile.
    - `let x: Stringable ; foo(x, String)`: `A` is inferred as `Stringable`.
- It would be possible to use named arguments in generic argument lists to explicitly specify some types and infer the rest.
  - `fun foo[A, B](a: A)`
    - `foo[where B is None](String)`: `A` is `String ref`, `B` is `None`.

# How We Teach This

This doesn't add new inference rules and people already familiar with type inference in Pony should feel fairly comfortable with it. A paragraph in the tutorial should be sufficient.

# Drawbacks

None.

# Alternatives

None.

# Unresolved questions

None.

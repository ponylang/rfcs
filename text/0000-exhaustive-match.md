- Feature Name: exhaustive-match
- Start Date: 2017-03-23
- RFC PR:
- Pony Issue:

# Summary

The compiler will no longer insert an implicit `else None` clause in `match` blocks where all possible types of the match expression are covered by pattern types of the cases.

# Motivation

In Pony, `match` is the preferred idiom for "unwrapping" a union type and passing control flow to different branches of code based on the matched type. For example, if matching on an expression of type `(A | B | C)`, the `match` block may have a case for each possible type in the union (`A`, `B`, and `C`), and within each case, the code may have access to the object with its type "unwrapped" as the matched type (instead of the less specific union type). This is only one of the uses of `match`, but it is a quite common one.

However, because the current compiler doesn't yet detect whether a match is exhaustive (whether all possible types are covered), the compiler automatically inserts an implicit `else None` in every `match` block that does not have an explicit `else` clause. This becomes problematic when trying to use the result of the `match` block in an outer expression, because it adds `None` to the possible types that may end up as the result. This in turn creates hassle for the programmer, as they are forced to deal with the fact that the type system believes `None` is a possibility, when in reality the `else` clause could never be reached.

The usual workaround is to create an explicit `else` clause with a "dummy value" of the right type (one of the types already being returned by the other case clauses). This is not always simple, as the types may not be trivially constructable. Even when it is simple to do, it's frustrating and ugly, especially when as a programmer it seems trivially obvious that the `match` is exhaustive.

The following motivating example from the standard library demonstrates this point of frustration:

```pony
  fun ref append(data: ByteSeq) =>
    """
    Add a chunk of data.
    """
    let data_array: Array[U8] val =
      match data
      | let data': Array[U8] val => data'
      | let data': String        => data'.array()
      else // unreachable
        recover val Array[U8] end
      end

    _available = _available + data_array.size()
    _chunks.push((data_array, 0))
```

When given a `ByteSeq` (which is defined as `(String | Array[U8] val`), this snippet intends to get an `Array[U8] val`, by either using the array given, or converting the string object to an array object. If we did this with no `else` clause, the result type would end up as `(Array[U8] val | None)`, so we are forced to use an explicit `else` clause which generates a dummy value of the right type (an empty `Array[U8] val`). An "unreachable" comment is used to highlight the hacky nature of the workaround and let the reader know that it's a dummy value.

This RFC proposes a design for having the compiler detect *most* useful cases of provable exhaustive match, and leaving out the implicit `else None` clause in these cases. There will be some contrived cases where exhaustive match is provable, but not recognized by the compiler, but even in these cases there should usually be a straightforward way to rewrite the cases so that the exhaustion will be detected.

# Detailed design

Every `match` block in the program that does not have an explicit `else` clause will be subject to the following process to detect if the cases form an exhaustive match. The cases will be iterated over, and each case will be evaluated to determine if the case is eligible for forming part of an exhaustive match.

A case is considered eligible if it has no guard expressions, and the pattern matches based on type alone. Additionally, cases that match on value are eligible, if the value is of a non-machine-word `primitive` type that does not define a custom `eq` method (which is used in `match` comparisons of structural equality). This is allowable because such primitives are singleton values, meaning that even though such cases are matching on value, they are still effectively matching only based on type. A case with a tuple pattern is considered eligible if all elements of the tuple are eligible patterns.

The following snippet gives some contrived example cases and shows whether they are eligible or not:

```pony
primitive P1
primitive P2
primitive P3

primitive CustomEq
  fun eq(that: CustomEq): Bool =>
    this isnt that

primitive Example
  fun apply(x: (String | U64 | (U64, Bool))) =>
    match x
    | let s: String       // ELIGIBLE - matches on type, captures the reference
    | let _: String       // ELIGIBLE - matches on type, discards the reference
    | let n: U64 if n > 4 // INELIGIBLE - has a guard
    | "hello world"       // INELIGIBLE - matches on value
    | P1 | P2 | P3        // ELIGIBLE - all match on value of basic primitive
    | 100                 // INELIGIBLE - primitive is a machine word value
    | CustomEq            // INELIGIBLE - primitive has a custom eq method
    | (let n: U64, true)  // INELIGIBLE - second element matches on value
    | (let n: U64, _)     // ELIGIBLE - value and type of 2nd element discarded
    end
```

Using those rules, the compiler will distinguish eligible cases from ineligible ones, and all eligible cases will each have their pattern type appended into a union type. If this union type is a supertype of the match expression type, then we can conclude that all possible cases are covered, and the match is exhaustive.

Each `match` block without an explicit `else` clause that is found to be exhaustive will be left without an `else` clause. Such `match` blocks that are not found to be exhaustive will have an implicit `else None` clause appended (as all such `match` blocks already are with the current compiler).

The code generator will have to be amended to know how to deal with `match` blocks that have no `else` clause.

This change will also apply to case functions "for free", because case functions are sugar for `match` blocks.

This change doesn't break any existing code.

It's worth mentioning that while cases with guards are considered ineligible for forming part of an exhaustive match, many real-world `match` blocks that include guards but are intended to be exhaustive can still be detected by the compiler as exhaustive, if written correctly.

For example, the following match clause is arguably exhaustive, but it would not be recognized as such by the compiler, because there is no case that covers the `U8` type that doesn't have a guard:

```pony
primitive Example
  fun apply(x: (U8 | String)) =>
    match x
    | let n: U8 if n < 10  => foo(n)
    | let n: U8 if n >= 10 => bar(n)
    | let s: String        => baz(s)
    end
```

However, the very same logic would be acheived if the guard were left out of the second case, taking advantage of the fact that only the first case that whose pattern matches will be selected.

```pony
primitive Example
  fun apply(x: (U8 | String)) =>
    match x
    | let n: U8 if n < 10 => foo(n)
    | let n: U8           => bar(n)
    | let s: String       => baz(s)
    end
```

In this rewritten form, both the second and third cases are eligible to be considered for exhaustive match, and together they do indeed form an exhaustive match over the match expression type, `(U8 | String)`.

# How We Teach This

The paragraph in the `match` section of the tutorial that mentions exhaustive match not being implemented yet should be updated to describe a basic summary of how exhaustive matches work.

In general, the above rules end up working basically everywhere you might intuitively expect exhaustive match to work. That is, overall, this system would work just like most users would expect, so detailed discussion of the internal rules used is outside the scope of the tutorial. Users who are curious about the underlying rules could be redirected here, to this RFC.

Additionally, anywhere in the standard library where exhaustive matches can improve the existing code, they should be used.

# How We Test This

Compiler tests should be added to test for common cases and edge cases of exhaustive and non-exhaustive matching.

# Drawbacks

* A user might become confused in situations where the match *seems* exhaustive, but isn't recognized as such by the compiler. However, this is already happening for *all* cases, so it's reasonable to believe that this feature will cause less confusion, not more.

# Alternatives

This is arguably a principle-of-least-surprise bug, so if we don't implement exhaustive match in the way outlined in this RFC, we need to implement it with some other (to be determined) approach. Not implementing exhaustive match isn't really an option - it's a question of when and how.

One aspect that isn't covered by this RFC is detecting and emitting a compiler error for redundant cases - cases whose type possibilities have already been exhausted by earlier cases, and so their code will never be reached. That feature could benefit from much of the same logic implemented for this RFC, but for now it's considered outside the scope of the RFC.

# Unresolved questions

None. The feature has already been implemented using this logic on my own fork of the compiler.

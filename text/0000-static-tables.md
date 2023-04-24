- Feature Name: Static Arrays of Numbers
- Start Date: 2023-04-24
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

This change adds the ability to define static tables of numbers in Pony programs.

# Motivation

The use case for this feature is to provide static tables of numeric data for use with algorithms like [Eisel-Lemire floating-point parsing](https://nigeltao.github.io/blog/2020/eisel-lemire.html) or [Ryu floating-point printing](https://github.com/ulfjack/ryu), both of which use large precalculated tables for performance.

The Pony compiler already does this for string literals; they are deduplicated and stored as static data.

# Detailed design

A static table can be included in a Pony program by prefixing its opening square bracket with a `#` charater.  This usage is analogous to the use of `#` to denote compile-time expressions in [Luke Cheeseman's dependent type proposal](https://github.com/lukecheeseman/ponyta).  For example, in the following code:

```pony
  let table: Array[U32] val =
    #[
      123
      456
    ]
```

The array's internal pointer will point to a static table.  The value of a static array literal can only be `Array[T] val`, where `T` is a floating-point or integral numeric type.

Ideally, the `Array` object itself will also be a static global object, so as to avoid constructing a new object every time we need to access the table, for instance if we're trying to use a table via a method on a primitive.

# How We Teach This

We will add a mention of this functionality in the [Tutorial section on array literals](https://tutorial.ponylang.io/expressions/literals.html#array-literals).  The keyword `static` is typically used in C-derived languages to denote global constant data, but is not otherwise used by Pony. Perhaps we could call these "compile-time constant" tables to fit with Luke Cheeseman's work.

No other Pony documentation needs to be changed for this RFC.

# How We Test This

This functionality will need unit tests to ensure that:

- Static array literals may never be aliased by mutable references.
- The emitted LLVM IR indeed stores and uses static data, instead of the current array literal implementation which constructs an `Array` object and then calls `add()` multiple times to add its contents.

We must ensure that the array literal and associated `Array` object are not able to be garbage-collected.

# Drawbacks

This change introduces a bit of new syntax which might be confusing to existing users.  It will not break any existing code.

# Alternatives

Instead of introducing new syntax, we could introduce a new type name, e.g. `StaticTable[T]` (with only `val` constructors) to which an array literal could be assigned; such array literals would be stored as static data, e.g. `let table: StaticTable[U32] = [ 123; 456 ]`.

We could modify the compiler to automatically store array literals assigned to `Array[T] val` variables as static data.  However this might be confusing to programmers as to what circumstances would trigger this magical behaviour.

If this RFC is not implemented, code that needs fast access to static data can currently use C FFI.

# Unresolved questions

Discussion is needed as to whether to use the `#` syntax or an alternative.

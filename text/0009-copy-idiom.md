- Feature Name: copy-idiom
- Start Date: 2016-07-21
- RFC PR: https://github.com/ponylang/rfcs/pull/22
- Pony Issue: https://github.com/ponylang/ponyc/issues/1138

# Summary

Extend the current idiom for object copying in the standard library with a `from` constructor in addition to the `clone` function.

# Motivation

The current "standard" way of copying an object is with the `clone` function (usual signature: `fun clone(): Object iso^`). While this function is very useful in some situations, like copying an `iso` object without consuming said object, it has limitations. For example it isn't possible to construct an embedded field with a copy of another object from the `clone` function because embedded fields have to be initialised from constructors. Adding copying constructors would solve that problem.

# Detailed design

The copying functions should be provided as:

```
class Object
  new from(that: Object box)

  fun clone(): Object iso^
```

This interface should only be a basic template and per-class modifications should be allowed, such as changing the reference capability of the return type of `clone`.

The `from` constructor on a given type `A` should be allowed to take objects of another type `S` if it makes sense to construct objects of type `A` from objects of any subtype of `S`.

On collections, `from` and `clone` should perform deep copies. We'll add a `Cloneable` interface to ensure that contained objects are indeed cloneables. Collections should provide a `shallow_from` constructor and a `shallow_clone` function for shallow copies.

## Changes to existing functions in the standard library

- `collections.List.from`, signature: `new from(seq: Array[A^])`. Would be modified to `new from(that: List[A] box)`. It is possible to construct `List`s from `Array`s by using `List.concat`.
- `collections.persistent.Lists.apply`, signature: `fun apply(arr: Array[val->A]): List[A]`. Would be removed. This function is redundant with `from`, which is taking a more generic `Iterator`.
- `collections.persistent.Maps.from`, signature (abridged): `fun from[K, V](pairs: Array[(K, V)]): Map[K, V]`. Would be modified to take an `Iterator`.

# How We Teach This

Advocating for the use of this idiom in user libraries would be good for the consistency of the Pony ecosystem. We could talk about object copying in the tutorial and recommend the `from` and `clone` names in copyable classes. It could be addressed in a new section in the Standard Library chapter named Idioms. This section would talk about general coding principles applicable across all the standard library and that users could apply to their own programs or libraries. Some discussion on what exactly would go in this section would be needed.

# Drawbacks

- This can introduce some code duplication between `from` and `clone`.
- The new shallow copy vs. deep copy distinction would break existing code.

# Alternatives

None.

# Unresolved questions

None.

- Feature Name: formal-viewpoint-adaptation
- Start Date: 2018-04-19
- RFC PR:
- Pony Issue:

# Summary

Adopt [George Steed's formal model for viewpoint adaptation][steed], including a new syntax for distinguishing between extractive and non-extractive viewpoint types.

[steed]: http://www.imperial.ac.uk/media/imperial-college/faculty-of-engineering/computing/public/GeorgeSteed.pdf

# Motivation

1. George Steed's formal model for viewpoint adaptation is the result of rigorous academic work, and provides formal rules to justify the resulting cap tables, in contrast to the current cap table we use, which is justified in an ad-hoc example-based way.

2. Adopting this model will allow the compiler to be more permissive, while remaining safe. That is, this model will allow the compiler to recognize a larger subset of safe programs as being safe, and allow them to compile as such.

3. Using formal rules for viewpoint-adapted capabilities will allow us to employ rule-based exhaustive testing of the capability type system for viewpoint adaptation, as we already are able to do for other areas of the capability type system.

# Detailed design

Currently Pony has one form of viewpoint adaptation, which is applied to test type safety of both extractive and non-extractive operations. After adopting the new model, Pony will have two distinct forms of viewpoint adaptation to represent the distinction between capability safety requirements for these two distinct kinds of operations. To quote [George Steed's paper on the subject][steed]:

> [Pony as it currently exists] defines just a single operator `[operator 1]` for both reading and writing the value of fields. We now split this definition in two as this allows us more room to optimise the definition and simplify the requirements of each operator independently: we reuse the original operator `[operator 1]` as non-extracting viewpoint adaptation (the capability obtained on field read) and define `[operator 2]` as extracting viewpoint adaptation (the capability of the old value of a field or variable returned by overwriting it).

The operators used in the paper are Unicode symbols that are difficult to type in a programming language on ASCII-based keyboards, but the current ASCII symbol used by the Pony language for viewpoint adaptation (referred to as `[operator 1]` in the quote above) is `->`. As in George Steed's paper, we would use this same operator to represent non-extractive viewpoint adaptation in the new model, and use a new operator for the extractive form (referred to as `[operator 2]` in the quote above). The ASCII symbol for extractive viewpoint adaptation would be `->>`.

Both the `->` and `->>` operators would be valid ways of viewpoint-adapting a type, with different meanings. The `->` operator would be the correct way of viewpoint-adapting a type when reading a field "normally", and the `->>` operator would be the correct way of viewpoint-adapting a type when doing a destructive read. The compiler would use different rules for each operator for determining the resulting capability.

The formal rules and capability tables from [George Steed's paper][steed] for each operation are reproduced below for convenience and clarity:

### Non-Extracting Viewpoint Adaptation

1. If either the origin or the field's cap is not writable (`val`, `box`, or `tag`), the viewpoint-adapted cap is also not writable.
2. If the field's cap is "globally compatible" with the cap of another reference to that same object (in a different actor's heap), then an alias of the viewpoint-adapted cap must also be globally compatible with the cap of the other reference.
3. If either of the following is true for two origin caps referring to the same object, then the alias of a viewpoint-adaptated cap from the first origin must be "locally compatible" (able to co-exist in the same actor's heap) with the viewpoint-adapted cap of the other origin to the same field:
  a. The two origin caps are "locally compatible", OR
  b. The two origin caps are identical and are not ephemeral.
4. If two origin caps referring to the same object are "globally compatible", then the alias of a viewpoint-adapted cap from any other origin cap must be "globally compatible" with the viewpoint-adapted cap to the same field from either of the other two origins.
5. If the origin cap is sendable, then the alias of the viewpoint-adapted cap must be globally compatible with any other origin's viewpoint-adapted cap for the same field.

Those rules yield the following cap table:

| origin | `->iso` | `->trn` | `->ref` | `->val` | `->box` | `->tag` |
|--------|---------|---------|---------|---------|---------|---------|
| `iso^` | `iso^`  | `iso^`  | `iso^`  | `val`   | `val`   | `tag`   |
| `iso`  | `iso`   | `iso`   | `iso`   | `val`   | `tag`   | `tag`   |
| `trn^` | `iso^`  | `trn^`  | `trn^`  | `val`   | `val`   | `tag`   |
| `trn`  | `iso`   | `trn`   | `trn`   | `val`   | `box`   | `tag`   |
| `ref`  | `iso`   | `trn`   | `ref`   | `val`   | `box`   | `tag`   |
| `val`  | `val`   | `val`   | `val`   | `val`   | `val`   | `tag`   |
| `box`  | `tag`   | `box`   | `box`   | `val`   | `box`   | `tag`   |
| `tag`  | N/A     | N/A     | N/A     | N/A     | N/A     | N/A     |

### Extracting Viewpoint Adaptation

1. If the field cap and another non-ephemeral cap referring the same object are "globally compatible", then the extracted-viewpoint-adapted cap of that field from any origin, must also be "globally compatible" (can co-exist in the program on the heaps of different actors).
2. If either of the following is true for two origin caps referring to the same object, then the alias of a viewpoint-adaptated cap from the first origin must be "locally compatible" (able to co-exist in the same actor's heap) with the viewpoint-adapted cap to the same field from the other origin, unaliased:
  a. The two origin caps are "locally compatible", OR
  b. The two origin caps are identical and are not ephemeral.

Those rules yield the following cap table:

| origin | `->>iso` | `->>trn` | `->>ref` | `->>val` | `->>box` | `->>tag` |
|--------|----------|----------|----------|----------|----------|----------|
| `iso^` | `iso^`   | `iso^`   | `iso^`   | `val`    | `val`    | `tag`    |
| `iso`  | `iso^`   | `val`    | `tag`    | `val`    | `tag`    | `tag`    |
| `trn^` | `iso^`   | `trn^`   | `trn^`   | `val`    | `val`    | `tag`    |
| `trn`  | `iso^`   | `val`    | `box`    | `val`    | `box`    | `tag`    |
| `ref`  | `iso^`   | `trn^`   | `ref`    | `val`    | `box`    | `tag`    |
| `val`  | N/A      | N/A      | N/A      | N/A      | N/A      | N/A      |
| `box`  | N/A      | N/A      | N/A      | N/A      | N/A      | N/A      |
| `tag`  | N/A      | N/A      | N/A      | N/A      | N/A      | N/A      |

# How We Teach This

The tutorial section on viewpoint adaptation would need to be rewritten and expanded.

Existing code in the standard library and examples would be refactored to take advantage of these improvements where appropriate, or to fix any breakages incurred.

# How We Test This

Extend exhaustive testing of capability operations to include the new formal rules for viewpoint-adaptation.

# Drawbacks

* Adds a new concept and new syntax to represent it in the language. This is more learning overhead for both new and existing users.

# Alternatives

- Use a different operator syntax for extractive viewpoint adaptation, rather than `->>`.

- Don't do this at all, and continue using an overly restrictive/simplistic model for viewpoint-adapted capabilities.

# Unresolved questions

I'd like someone more familiar with George Steed's paper to verify my "layman's rendering" of the formal rules from the paper. I translated these from the formal notation of the paper, and I want to make sure the understanding/sentiment is still correct.

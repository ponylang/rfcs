- Feature Name:unsafe-operators 
- Start Date: 2016-10-20
- RFC PR:
- Pony Issue:

# Summary

Add a set of operators mapping to the unsafe math operations.

# Motivation

As discussed in ponylang/ponyc#993, it has been decided to separate the various mathematical and logical operations in the Pony language into two separate sets, a set of functions with fully defined semantics and another set of functions that can have undefined results but can have better performance.

Since `x + y` is more convenient than `x.add(y)`, we also need to come up with operators sugaring to the `*_unsafe` functions.

# Detailed design

The proposed syntax is `op~`. The full list of required operators is

- `+~` (`add_unsafe`)
- `-~` (`sub_unsafe`)
- `*~` (`mul_unsafe`)
- `/~` (`div_unsafe`)
- `%~` (`mod_unsafe`)
- `<<~` (`shl_unsafe`)
- `>>~` (`shr_unsafe`)
- `==~` (`eq_unsafe`)
- `!=~` (`ne_unsafe`)
- `<~` (`lt_unsafe`)
- `>~` (`gt_unsafe`)
- `<=~` (`le_unsafe`)
- `>=~` (`ge_unsafe`)

Bitwise `not`, `or` and `and` are always fully defined so there is no need for unsafe operations there.

# How We Teach This

This should be mentioned in the future documentation for unsafe operations. Unsafe operators could be described quickly in the basic arithmetic section of the tutorial as a mean for advanced users to get better performance. In addition, the new symbols will have to be added to the symbol appendix in the tutorial.

# Drawbacks

None.

# Alternatives

Don't add anything and use the full function names. This would probably be inconvenient since we're talking about common mathematical functions.

# Unresolved questions

Another syntax can be considered, if suggested.

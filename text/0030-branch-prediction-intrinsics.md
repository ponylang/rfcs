- Feature Name: branch-prediction-intrinsics
- Start Date: 2016-10-17
- RFC PR: https://github.com/ponylang/rfcs/pull/44
- Pony Issue: https://github.com/ponylang/ponyc/issues/1500

# Summary

Add program annotations to control structures to enable the user to make the optimiser aware of the likelihood of a given condition.

# Motivation

Users often know more than the optimiser about the high level properties of their code. Having these annotations would allow users to give hints to the optimiser for better code generation.

# Detailed design

Add `likely` and `unlikely` annotations able to affect the `if`, `elseif`, `while` and `until` control structures, as well as individual cases of a match expression (by annotating the `|` symbol).

When a `likely` conditional branch is evaluated, the optimiser is allowed to assume that the associated value is probably true and to generate code with fast execution paths where the branch is taken. `unlikely` works the same way but assumes that the branch is probably not taken. There are two annotations to avoid weird reversed conditions in some cases.

Examples:

As data on high-level properties.

```pony
fun process(id: USize) =>
  if \likely\ id == _common_id then
    // process common IDs
  else
    // process other IDs
  end
```

As an optimisation when function contracts are violated.

```pony
fun sqrt(x: F64): F64 ? =>
  if \unlikely\ x < 0 then
    error
  end
  // compute square root
```

# How We Teach This

This is a basic concept, the documentation string should be sufficient. In addition, a Pony pattern with practical examples could be useful.

We'll also want to stress that these annotations are mainly intended for performance critical code and that the cost of being wrong can be significant.

# How We Test This

These annotations will directly map to LLVM's intrinsics and metadatas. We would assume that their implementation works.

# Alternatives

- Use compiler intrinsic functions instead of annotations. This has been strongly considered in a previous draft of the RFC but was dropped because of implementation concerns with the Pony compiler intrinsics and the LLVM constructs for branch prediction.
- Introduce new keywords, for example `iflikely`. This has also been considered in a previous draft but was dropped to avoid cluttering the syntax of the language.

Not implementing these annotations would leave users without any way to influence branch prediction. The only possible impact of a user getting it wrong would be decreased performance and it wouldn't raise correctness issues.

# Unresolved questions

None.

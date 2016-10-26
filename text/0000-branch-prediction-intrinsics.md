- Feature Name: branch-prediction-intrinsics
- Start Date: 2016-10-17
- RFC PR:
- Pony Issue:

# Summary

Add variations of control structures to enable the user to make the optimiser aware of the likelihood of a given condition.

# Motivation

Users often know more than the optimiser about the high level properties of their code. Having these constructs would allow users to give hints to the optimiser for better code generation.

# Detailed design

Add `likely` and `unlikely` suffixes to the `if`, `elseif`, `while` and `until` control structures. These variations are also added to `match` statements, with the following syntax.

```pony
match x
| likely None => // ...
| unlikely let x': A => // ...
end

When a `likely` conditional branch is evaluated, the optimiser is allowed to assume that the associated value is probably true and to generate code with fast execution paths where the branch is taken. `unlikely` works the same way but assumes that the branch is probably not taken. There are two constructs to avoid weird reversed conditions in some cases.

The base construct and the variations are considered equivalent from the grammar standpoint so it is possible to write this kind of construct:

```pony
iflikely a then
  // ...
elseif b then
 // ...
elseifunlikely c then
 // ...
end

Examples:

As data on high-level properties.

```pony
fun process(id: USize) =>
  iflikely id == _common_id then
    // process common IDs
  else
    // process other IDs
  end
```

As an optimisation when function contracts are violated.

```pony
fun sqrt(x: F64): F64 ? =>
  ifunlikely x < 0 then
    error
  end
  // compute square root
```

# How We Teach This

This is a basic concept, the documentation string should be sufficient. In addition, a Pony pattern with practical examples could be useful.

We'll also want to stress that these construct are mainly intended for performance critical code and that the cost of being wrong can be significant.

# How We Test This

These constructs will directly map to LLVM's intrinsics and metadatas. We would assume that their implementation works.

# Drawbacks

- `likely` and `unlikely` would become reserved keywords.
- `elseifunlikely` is a quite convoluted keyword.

# Alternatives

Use compiler intrinsic functions instead of keywords. This has been strongly considered in a previous draft of the RFC but was dropped because of implementation concerns with the Pony compiler intrinsics and the LLVM constructs for branch prediction.

Not implementing these constructs would leave users without any way to influence branch prediction. The only possible impact of a user getting it wrong would be decreased performance and it wouldn't raise correctness issues.

# Unresolved questions

The actual syntax, particularly for `match`, is up for discussion.

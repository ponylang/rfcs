- Feature Name: branch-prediction-intrinsics
- Start Date: 2016-10-17
- RFC PR:
- Pony Issue:

# Summary

Add compiler intrinsics allowing the user to make the optimiser aware of the likelihood of a given condition.

# Motivation

Users often know more than the optimiser about the high level properties of their code. Having these intrinsics would allow users to give hints to the optimiser for better code generation.

# Detailed design

Add the following to the `builtin` package.

```pony
primitive Likely
  fun apply(value: Bool): Bool =>
    compile_intrinsic

primitive Unlikely
  fun apply(value: Bool): Bool =>
    compile_intrinsic
```

`Likely.apply` and `Unlikely.apply` return `value` unchanged.

When `Likely.apply(value)` is evaluated, the optimiser is allowed to assume that `value` is probably true and to generate code with fast execution paths where `value` is indeed true. `Unlikely.apply` works the same way but assumes that `value` is probably false. There are two intrinsics to avoid weird reversed conditions in some cases.

Examples:

As data on high-level properties.

```pony
fun process(id: USize) =>
  if Likely(id == _common_id) then
    // process common IDs
  else
    // process other IDs
  end
```

As an optimisation when function contracts are violated.

```pony
fun sqrt(x: F64): F64 ? =>
  if Unlikely(x < 0) then
    error
  end
  // compute square root
```

# How We Teach This

This is a basic concept, the documentation string should be sufficient.

# How We Test This

These intrinsics will directly map to LLVM's intrinsics. We would assume that their implementation works.

# Drawbacks

None.

# Alternatives

Not implementing these intrinsics would leave users without any way to influence branch prediction. The only possible impact of a user getting it wrong would be decreased performance and it wouldn't raise correctness issues.

# Unresolved questions

None.

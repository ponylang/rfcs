- Feature Name: optimisation-inhibition
- Start Date: 2016-05-27
- RFC PR:
- Pony Issue:

# Summary

Add various Pony `compile_intrinsic` functions preventing some compiler optimisations such as dead code removal.

# Motivation

In some very specific domains such as benchmarking, some compiler optimisations are really bad. In particular, we do not want the benchmarked code to be eliminated even if it has no side-effects from the optimiser standpoint.

# Detailed design

Since we're talking about benchmarking and performance analysis, this new construct must

- allow really fine-grained control: keep as little code as possible.
- not introduce any additional cost: no function call, no register/memory assignment, nothing.

In C, this is possible by using inline assembly marked `volatile`. For example:

```c
void do_not_optimise(void* p)
{
    asm volatile("" : : "g"(p) : "memory");
}

void observe()
{
    asm volatile("" : : : "memory");
}

int main(void)
{
    int a = 0;
    do_not_optimise(&a);
    a = 42;
    observe();
}
```

Without the use of `do_not_optimise`, the variable `a` would be eliminated by the optimiser. Here, it is kept on the stack and initialised to 0. The call to `observe` prevents the removal of the modification of `a` to 42. No additional instruction is inserted in the final assembly code.

In Pony, we do not have inline assembly but fortunately we can generate it via LLVM. It would be easy to replicate `do_not_optimise` and `observe` as Pony `compile_intrinsic` functions. These functions should be sufficient to prevent most cases of code elimination in Pony. If uncovered cases are discovered, we can add new functions.

## Pony interface

Add the following to the `builtin` package.

```pony
primitive DoNotOptimise
  """
  Contains functions preventing some compiler optimisations, namely dead code
  removal. This is useful for benchmarking purposes.
  """

  fun apply[A](obj: A) =>
    """
    Prevent the compiler from optimising out obj and any computation it is
    derived from.
    """

    compile_intrinsic

  fun observe() =>
    """
    Prevent the compiler from optimising out writes to an object marked by
    `DoNotOptimise.apply`.
    """

    compile_intrinsic
```

`DoNotOptimise.apply` is generic to avoid boxing machine words, as the overhead is unacceptable.

The `DoNotOptimise.apply` function shall compile down to the following (pseudo-)LLVM IR.

```llvm
call void asm sideeffect "", "imr,~{memory}"(A obj)
```

The `DoNotOptimise.observe` function shall compile down to the following LLVM IR.

```llvm
call void asm sideeffect "", "~{memory}"()
```

# How We Teach This

This is clearly an advanced feature and people unfamiliar with performance analysis and compiler optimisations will probably get it wrong a few times. In addition to the documentation, this could be the subject of a Pony pattern.

# Drawbacks

None.

# Alternatives

None.

# Unresolved questions

None.

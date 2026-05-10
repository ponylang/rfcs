- Feature Name: trust-boundary-specification
- Start Date: 2018-04-21
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Clearly define what the trust boundary means to the language, and what can happen when it is violated.

# Motivation

Currently, the trust boundary is very loosely defined. The gist of the current definition is that a Pony program cannot crash unless it uses the FFI, in which case anything can happen. There are several issues here:

- There are unsafe operations available in Pony (e.g. unsafe maths) that aren't covered by the trust boundary. In addition, unsafe operations are currently quite limited. With a proper framework, we could add more "dangerous" operations like raw pointer operations.
- "Anything can happen" is a bad definition for the compiler. There are different kinds of undefined behaviour, and refining the definition will make the difference between a valid and an invalid optimisation clearer.
- A program can crash even without doing any unsafe operation, for example by running out of memory.

The goals of this RFC are to:

- Cover every current and future unsafe operation with the trust boundary rules (to the user, this means a variation of the `--safe` compiler flag.)
- Give a clear framework to compiler implementations as to which optimisations are and aren't permitted.
- Cover out-of-memory errors in the language semantics.

# Detailed design

## Language semantics

The following rules will be added to the language semantics. 

### As-if rule

The compiler is allowed to perform any change to the program as long as the following remains true.

- At the end of a behaviour, the associated actor is exactly in the state it would be if the program was executed as written.
- If an object or actor has a finaliser, that finaliser will eventually be called exactly once. The finaliser will only be called once no actor has a reference to the object.
- Inside of a given behaviour, messages are sent as if the behaviour was executed as written, in the same order and with the same contents.
- FFI calls are executed as if the behaviour was executed as written, in the same order and with the same arguments.
  - Calls to runtime functions (starting with `pony_`) are free from this rule and the following one, as long as every other rule is respected.
- Message sends and FFI calls are not reordered with respect to each other.
- The program terminates if and only if quiescence has been reached.
- Object and reference capability security is maintained for every object in the program. This means that:
  - References always refer to valid objects.
  - A reference of static type `T` has a dynamic type of either `T` or a subtype of it.
  - If an object is accessible in a given scope, the object was either created in that scope, or a reference to it was passed to that scope.
    - If the scope in question is an actor and that actor didn't create the object, the reference to the object was received in a message.
  - Every local (resp. global) alias of a reference with capability `k` is locally (resp. globally) compatible with `k`.
  - Reference capability aliasing from `k` to `k'` can only be done if `k` is a subtype of `k'`.

### Undefined results

The evaluation of an operation with undefined results produces an undefined, stable value. That is, while the bit pattern of the value is undefined, it cannot "magically" change once assigned to a variable or passed as an argument. However, different evaluations of the same expression with undefined results **can** produce different values. In addition:

- Every subsequent expression depending on undefined results also has undefined results. Memory reads from a given memory location depend on the last write to that memory location, and method parameters (including behaviours) depend on their respective arguments.
- If the conditional of a branching construct or the operand of a pattern match has undefined results, the branch taken is undefined. The undefined results do not propagate to the expressions in the branch.
- The implementation is allowed to provoke abnormal program termination. The exact process of that termination is unspecified.

Undefined results do not invalidate capability security guarantees. This means that even though an object reference can have undefined results, that reference must always refer to an object of the correct type and reference capability.

Examples of Pony operations that can have undefined results include unsafe maths operations, like unchecked division.

### Undefined behaviour

If an expression with undefined behaviour is evaluated, or if the program does a FFI call with undefined behaviour (as defined by the specification of the language the called function is written in), every behaviour in the program is free from the as-if rule, including the capability security guarantees. Conversely, violating the capability security guarantees in an unsafe operation or FFI call results in undefined behaviour.

Examples of Pony operations that can have undefined behaviour include raw pointer operations (not available currently).

### Out-of-memory errors

When encountering an unrecoverable out-of-memory situation (e.g. a very deep recursion, an object allocation failure, etc.) the program is required to terminate and to print an explanatory error message to the user.

### The new trust boundary

The new trust boundary will be separated into multiple levels, with increasing permissiveness. Each level includes the permissions of the previous levels.

- At the first level, a package is allowed to do operations that can have undefined results.
- At the second level, a package is allowed to do operations that can have undefined behaviour.
- At the third level, a package is allowed to do FFI calls.

The main reason for separating undefined behaviour operations and the FFI into different levels is for general side-effect control. An FFI call can do _anything_, including writing to files or to the network, but a Pony operation with potential undefined behaviour has a limited scope.

Out-of-memory errors aren't covered by the trust boundary because trying to do so would greatly limit the usefulness of untrusted packages.

## User-facing changes

### In the compiler

With the trust boundary now being split into multiple levels, the `--safe` flag must also be separated into multiple levels. The new flags, `--safe-1`, `--safe-2`, and `--safe-3`, can be used in the same way as `--safe` to specify the trust level of packages in the program. `--safe` will be removed.

- Higher-level flags take precedence over lower-level flags.
- In the same way `--safe` works currently, if any of those flags is specified, any package not in the trusted list is treated as untrusted.
- If none of those flags are specified, all packages are treated as trusted with a level of 3.
- The `builtin` package is always treated as trusted with a level of 3.

### In the language

New syntax is needed to mark unsafe operations. We propose to use new annotations for this purpose: `unsafe-1`, `unsafe-2` and `unsafe-3`. These annotations map directly to the various levels of the trust boundary. These annotations are only allowed on function definitions, for example `fun \unsafe-1\ foo()`.

Flags (`safe`) and annotations (`unsafe`) use antonyms because the intended wording of this syntax is "the most trusted package is allowed to use the most unsafe operation".

- An unsafe function can only be called from a package with the corresponding trust level or higher.
- A package can only define unsafe functions if it has the corresponding trust level or higher.
- Safety level is taken into account in function subtyping, with safer functions (e.g. `unsafe-1`) being subtypes of less safe functions (e.g. `unsafe-3`).

`unsafe-3` is intended for operations that can have an unlimited scope. For example, an operation composed of multiple FFI calls.

### In the standard library

Unsafe maths functions on numeric primitives will be marked `unsafe-1`. There is nothing requiring to be marked `unsafe-2` or `unsafe-3` currently so these annotations will stay unused for now.

# How We Teach This

An new subsection in the FFI section of the tutorial will be added, explaining the various levels of unsafe operations. The docstring of each unsafe operation in the standard library will be updated to include the safety level.

# How We Test This

Compiler tests will be added, testing the accessibility of unsafe functions from packages of varying trust levels, and testing unsafe function subtyping.

# Drawbacks

This will break compatibility with tools using the `--safe` flag, as this flag will be removed. This also has the potential to break compatibility with programs using the current unfettered unsafe operations in the standard library in conjunction with `--safe`. These two cases are probably very marginal.

# Alternatives

In general, the author of this RFC believes that specifying the trust boundary in a more formal manner is necessary, for the various reasons detailed in the Motivation section of this RFC. It would be possible to relax or constrain the proposed rules to respectively support a broader range of implementations or to enable more aggressive optimisations. The proposed rules strive to strike a balance between these two considerations.

# Unresolved questions

None.

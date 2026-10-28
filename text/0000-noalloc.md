- Feature Name: noalloc
- Start Date: 2026-07-03
- RFC PR:
- Pony Issue: https://github.com/ponylang/ponyc/pull/6309

# Summary

A `noalloc` annotation on a method: a function, a behavior, or a constructor. The compiler proves, in release builds, that the method's body allocates nothing on the heap. It checks not just the body but everything the body transitively calls, whether or not those callees are annotated. If anything allocates, the build fails and reports where the allocation is. The annotation can also go on a trait method, which requires every implementer to be `noalloc`.

# Motivation

If you write high-performance code in Pony, you already watch your allocations. The performance cheat sheet tells you to, and in a hot path you do, because allocation is a cost you can't afford there.

The hard part is keeping it that way. You write the hot path, you check it doesn't allocate, it ships. Six months later someone edits a helper three calls down, or a dependency bumps a version, and now the path allocates every time it runs. Nothing tells you. The build is green. The tests pass. You find it with a profiler, in production, after it has already cost you.

`noalloc` is the tool for that. You mark the hot method, and the compiler keeps it allocation-free, now and into the future. It fails the build the moment anything the method reaches starts allocating, including code you did not write and did not annotate. A regression anywhere under a `noalloc` method is a compile error.

# Detailed design

## The annotation

`noalloc` uses Pony's annotation syntax, placed after the keyword:

```pony
fun \noalloc\ checksum(data: Array[U8] box): U32 =>
  var acc: U32 = 0
  var i: USize = 0
  while i < data.size() do
    try acc = acc + data(i)?.u32() end
    i = i + 1
  end
  acc
```

It declares that running `checksum` allocates nothing on the heap. Not the arithmetic, not the loop, and not anything `checksum` calls in turn.

"Allocates nothing on the heap" means every allocation that survives to the shipped binary is a stack allocation. The check scans the optimized IR for surviving calls to the runtime's allocation functions: `pony_alloc`, `pony_alloc_small`, and `pony_alloc_large` (and their `_final` variants for objects with finalizers) for a heap object or a boxed value, `pony_realloc` for a growing array or string, `pony_alloc_msg` for a message send, and `pony_create` for an actor creation. A heap object, a boxed value, a message send, and an actor creation all bottom out in one of those calls, so they fall under one rule instead of a list of special cases. A stack allocation is not one of those calls, so it passes.

## What can be marked

`noalloc` describes what a method's body does when it runs: the allocations the code performs, not the cost of invoking it. That distinction is what lets the annotation go on a `fun`, a `be`, and a `new`, even though calling a behavior or a constructor allocates.

Calling a `fun` allocates nothing on its own, so for a function there is no distinction to draw. `fun \noalloc\ f()` means the body, and everything it calls, allocates nothing.

Calling a `be` allocates a message. That allocation is the cost of the send, and it happens at the call site, charged to whoever sends the message. It is not part of the behavior's body. So a behavior can be `noalloc`, and it is a promise about the work the behavior does when the actor runs it, not about the send that delivered the call:

```pony
be \noalloc\ add(n: U64) =>
  _sum = _sum + n
```

Calling a `new` allocates the object being constructed. Same shape: that allocation is the cost of construction, charged to whoever calls `new`. `new \noalloc\` promises the constructor's body allocates nothing beyond the object itself:

```pony
new \noalloc\ create(x: U64, y: U64) =>
  _x = x
  _y = y
```

A constructor that sets numeric fields, like that one, is `noalloc`. A constructor that builds a backing array for a field is not, because the array is a second allocation the body performed, on top of the object being constructed.

The send and the construction are checked against the calling code, where they happen. The body is checked against its own annotation.

A `noalloc` body still cannot send a message, because a message always escapes to another actor and can never be a stack allocation. For the same reason, a `noalloc` body cannot create an actor: creating an actor allocates the actor on the heap and sends it a message to start its lifecycle, neither of which can be a stack allocation. So a `noalloc` behavior is one whose body does synchronous work, does not fan out further sends, and does not create actors. That keeps `noalloc` to synchronous, non-sending computation: parsers, codecs, buffer manipulation, math on a hot loop.

## Non-local checking

The annotation is verified by checking the method's body and, transitively, every method it calls. A callee that is itself marked `noalloc` is taken as given, because it was verified at its own definition. A callee that is not annotated has its body checked in turn. If any method reachable from the `noalloc` method has a heap allocation that survives to the shipped code, the `noalloc` method fails to compile.

None of the code a `noalloc` method calls has to be annotated. That is the point. You can put `noalloc` on a method that calls `stdlib`, or a library you cannot edit, and the guarantee still holds, because the compiler computes the allocation behavior from the code rather than from annotations the callees would have to carry. The un-annotated callee is not itself required to be allocation-free; it is free to allocate. It just cannot be reached from a `noalloc` method if it does.

The cost of this is that a `noalloc` method is coupled to code elsewhere. A change far away can break it. That is the feature working, and it is also a genuine drawback, covered below.

## Checked in release, not debug

The `noalloc` annotation is part of the signature and is always type-checked for conformance, in every build. Whether a method's body actually satisfies the annotation is verified only in release.

The verification runs on the optimized code, after the heap-to-stack pass, and in a debug build those passes have not run. A release build keeps short-lived objects on the stack that a debug build leaves on the heap, so verifying a debug build would reject methods that allocate nothing in the artifact you actually ship. The guarantee is about the shipped binary, so it is checked against the shipped binary.

So a `noalloc` method whose body allocates still compiles in a debug build, unverified, and fails only in release. Do not rely on `noalloc` holding while you develop at `-d`. It holds in the build you ship.

## After heap-to-stack

ponyc already has a pass that promotes a heap allocation to a stack allocation when it can prove the object does not escape. Because the check runs after it, an allocation the pass moved to the stack passes. That is correct, not a loophole: an object on the stack is a stack allocation, and `noalloc` allows those. What it started as in the source does not matter; the check flags only allocation that survives off the stack.

## What the error says

The error names the `noalloc` method that failed, what kind of allocation it performs — a heap allocation, a message send, or an actor creation — and the source location of the specific allocation call (file, line, column). The source location survives because the check runs on LLVM IR that still carries debug location metadata from the original source.

The path from the `noalloc` method down to the allocation is not reported — only the endpoints: which `noalloc` method failed and which allocation call caused it. When the allocation is several calls deep, the user sees the top and the bottom but not the intermediate functions.

When a `noalloc` method reaches more than one allocation, the error reports the first one found in the optimized IR. Each `noalloc` method is checked independently, so multiple failing `noalloc` methods each get their own error, but a single one that reaches several allocations gets one error for the first.

## Traits

A method on a trait can be marked `noalloc`. When it is, every implementer's version of that method must be `noalloc` as well.

```pony
trait Digestible
  fun \noalloc\ digest(): U64
```

Any class that is `Digestible` must provide `digest` as `noalloc`. An implementer that allocates fails at its own definition, not at some distant call site that dispatches through `Digestible`:

```pony
class SlowDigest is Digestible
  fun \noalloc\ digest(): U64 =>
    let parts = recover Array[U64] end  // heap allocation
    // ...
```

This follows the same variance as `?`. A trait method declared partial can be implemented by a total one, but not the reverse. `noalloc` is the same kind of relationship: an implementer can strengthen (be `noalloc` where the trait does not require it) but cannot weaken (allocate where the trait requires `noalloc`).

`noalloc` is not allowed on interface methods. Interfaces are structural: any type whose methods match satisfies the interface without declaring conformance. Putting `noalloc` on an interface method would change which types satisfy it — a class that never asked to implement the interface would stop matching because its method is not `noalloc`. That breaks the structural model. Traits are nominal — a class opts in with `is MyTrait`, so requiring its method to match `noalloc` is a contract the class agreed to.

The reason this matters is virtual calls, below.

## Virtual calls

A call through a trait or interface resolves to a concrete method at runtime. Which one runs is not known at compile time, so the non-local check cannot trace it to a concrete body.

For traits, the answer is the `noalloc` annotation on the trait method. Inside a `noalloc` method, a virtual call through a trait is only allowed when the trait method is itself marked `noalloc`:

```pony
fun \noalloc\ mix(items: Array[Digestible] box): U64 =>
  var acc: U64 = 0
  var i: USize = 0
  while i < items.size() do
    try acc = acc xor items(i)?.digest() end
    i = i + 1
  end
  acc
```

Because `Digestible.digest` is `noalloc`, every type that is `Digestible` has a `noalloc` `digest`, so the call is allocation-free no matter which one runs. A virtual call through a trait method that is not marked `noalloc` is a compile error inside a `noalloc` method.

For interfaces, there is no annotation to rely on — `noalloc` is not allowed on interface methods. A virtual call through an interface from a `noalloc` method is not currently verifiable. See the unresolved questions for the path forward.

## FFI calls and bare lambdas

A `noalloc` method cannot call a C function through FFI, and it cannot call a bare lambda. Both are opaque to the compiler: an FFI call is an external declaration with no body to inspect, and a bare lambda call is an indirect call through a function pointer that cannot be resolved to a target. In either case, the compiler cannot determine whether the callee allocates internally, so it rejects the call.

This is enforced at two levels. The expression pass rejects an FFI call or a bare lambda call that appears directly in a `noalloc` method body. The LTO pass rejects any call to an external declaration (that is not a known allocation function or an LLVM intrinsic) and any indirect call through a function pointer that appears in the transitive call graph of a `noalloc` function. The expression pass catches the common case early with a clear source-level error; the LTO pass catches the transitive case, where a `noalloc` method calls an unannotated Pony method that itself calls FFI or dispatches through a bare lambda.

The restriction is strict: a `noalloc` method cannot reach any C code, even runtime C shims that do not allocate, and cannot dispatch through bare lambdas, even ones whose target is allocation-free. There is no opt-in mechanism to mark an FFI call or bare lambda as safe. This closes the verification gap entirely — `noalloc` means the compiler checked every call in the chain, with no holes at trust boundaries.

## What callers get

A `noalloc` method makes a stronger promise than an unannotated one, so it can be called anywhere an unannotated method is expected. That is the modular half of the design: annotate a reusable method once, and every `noalloc` caller relies on it without re-checking its body.

# How We Teach This

`noalloc` is another program annotation, so it is taught as an addition to the "Program Annotations" section of the tutorial, a continuation of what is already there rather than a new concept. It sits with `\packed\` and `\nosupertype\`, the annotations the compiler acts on, not with the ones it is free to ignore.

The addition needs to cover three things the existing annotations don't raise:

- It is enforced. Violating `noalloc` is a compile error, which is the line between it and a hint like `\likely\`.
- The body-versus-call distinction, because `noalloc` on a behavior or constructor reads as a contradiction until it is spelled out. Calling a behavior allocates a message and calling a constructor allocates an object, but `noalloc` is a promise about the body, and that allocation is the caller's cost. The `be` and `new` cases have to be shown directly; the `fun` case never surfaces the distinction and a reader will not infer it.
- The non-local checking, which is the part that surprises people. You annotate the hot method, not what it calls, and the compiler walks the call tree, so a `noalloc` method can break from a change in a file the author never opened. The comparison to lead with is `?`: a checked property in the signature that implementers must match. Anyone who understands `?` understands the shape of `noalloc`.

Existing users who already read the annotations page will not return to a section they think they know, so the addition needs a note in Last Week in Pony announcing it. That is how someone who read that page a year ago finds out `noalloc` exists.

The performance cheat sheet already has a "watch your allocations" section, and that is where someone worried about allocation goes looking. It should carry a note that `noalloc` exists, a pointer from the general advice to the tool that enforces it.

# How We Test This

The tests are compiler tests in the ponyc test suite, at three layers.

**Syntax.** Small programs that exercise where the annotation is accepted and rejected. `noalloc` on a `fun`, `be`, and `new` compiles; `noalloc` on a class or actor declaration does not; `noalloc` on an interface method does not. An FFI call inside a `noalloc` method does not compile; a bare lambda call inside a `noalloc` method does not compile.

**Conformance.** Subtyping checks at the type level. A class implementing a `noalloc` trait method with a `noalloc` method compiles; the same class without `noalloc` on its method does not. A `noalloc` method that makes a virtual call through a non-`noalloc` interface or trait method does not compile; the same call through a `noalloc` trait method does.

**LTO pass.** The allocation check itself, run on optimized LLVM IR. Each test compiles a small program in release mode, runs the heap-to-stack pass and then the `NoAllocCheck` pass, and asserts whether an allocation violation was diagnosed. Pure arithmetic passes. A `noalloc` method that allocates a `String` fails. A `noalloc` method that transitively calls an allocating method fails. A `noalloc` method that calls another `noalloc` method passes. A `noalloc` behavior with a pure body passes. A `noalloc` method that transitively reaches an external declaration (via an unannotated Pony callee that calls FFI) fails. A `noalloc` method that transitively reaches an indirect call (via an unannotated Pony callee that calls through a bare lambda) fails.

# Drawbacks

- **No signal in debug builds.** The body is verified only in release. While you develop at `-d`, a `noalloc` method that allocates compiles clean. You find the regression when you build release.

- **A `noalloc` method is coupled to the whole program.** Non-local checking means a change in distant code can break it, and the error surfaces at the annotated method rather than at the change. This is the same property that makes the feature useful, but it is a real cost: a `noalloc` method is not something you can fully reason about by reading it alone.

- **`noalloc` adds type-system surface.** It is a new signature property with variance and conformance rules on traits. That is more to specify, implement, and teach than a feature that stays out of the type system.

- **Virtual calls through interfaces are not supported.** Inside a `noalloc` method, dispatch through a trait requires the trait method to be `noalloc`. Dispatch through an interface is not currently verifiable, so a virtual call through an interface is a compile error inside a `noalloc` method.

- **FFI and bare lambdas are not allowed.** A `noalloc` method cannot call C code through FFI or dispatch through a bare lambda, because the compiler cannot inspect the callee's body. This is restrictive — it rules out C functions that do not allocate and bare lambdas whose targets are allocation-free. There is no way to mark an opaque call as safe.

- **What passes depends on the optimizer.** The check runs on the optimized artifact, so what satisfies it depends on what the heap-to-stack pass and the rest of the release pipeline remove. That is inherent to checking the code you actually ship, and it cuts both ways: you gain when the optimizer improves, and a change to the optimizer can change what compiles.

- **Implementation cost.** This needs a whole-program analysis that computes allocation behavior per method, run after optimization, plus the conformance checking for `noalloc` on traits.

# Alternatives

**Local checking with required annotations.** Require every callee of a `noalloc` method to be declared `noalloc` too, and check each method only against its callees' declarations rather than their bodies. This gives local reasoning: a method can be understood from its own text, and a distant change cannot silently break it. It is rejected because it cannot do the main thing the motivation asks for. To mark a hot path that calls `stdlib`, every `stdlib` method on that path would have to be annotated first. You cannot protect a hot path built on code that has not opted in. Non-local checking does not need cooperation from the callees, and that is what lets the annotation go onto existing code.

# Unresolved questions

- **How should virtual calls through interfaces work in `noalloc` paths?** `noalloc` is not allowed on interface methods because interfaces are structural and the annotation would change which types satisfy them. That leaves virtual calls through interfaces unverifiable inside a `noalloc` method. A closed-world analysis at the dispatch site — checking all types that could be the runtime target — could verify that every possible implementer's method is allocation-free, without requiring the annotation on the interface itself. Whether that analysis is practical, and what the error looks like when one implementer out of many allocates, is open.

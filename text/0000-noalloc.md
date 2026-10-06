- Feature Name: noalloc
- Start Date: 2026-07-03
- RFC PR:
- Pony Issue:

# Summary

A `noalloc` annotation on a method: a function, a behavior, or a constructor. The compiler proves, in release builds, that the method's body allocates nothing on the heap. It checks not just the body but everything the body transitively calls, whether or not those callees are annotated. If anything allocates, the build fails and reports the method that allocates. The annotation can also go on an interface or trait method, which requires every implementer to be `noalloc`.

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

"Allocates nothing on the heap" means every allocation that survives to the shipped binary is a stack allocation. The check scans the optimized IR for surviving calls to the runtime's allocation functions: `pony_alloc`, `pony_alloc_small`, and `pony_alloc_large` (and their `_final` variants for objects with finalizers) for a heap object or a boxed value, `pony_realloc` for a growing array or string, and `pony_alloc_msg` for a message send. A heap object, a boxed value, and a message send all bottom out in one of those calls, so they fall under one rule instead of a list of special cases. A stack allocation is not one of those calls, so it passes.

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

A `noalloc` body still cannot send a message, because a message always escapes to another actor and can never be a stack allocation. So a `noalloc` behavior is one whose body does synchronous work and does not fan out further sends. That keeps `noalloc` to synchronous, non-sending computation: parsers, codecs, buffer manipulation, math on a hot loop.

## Non-local checking

The annotation is verified by checking the method's body and, transitively, every method it calls. A callee that is itself marked `noalloc` is taken as given, because it was verified at its own definition. A callee that is not annotated has its body checked in turn. If any method reachable from the `noalloc` method has a heap allocation that survives to the shipped code, the `noalloc` method fails to compile.

None of the code a `noalloc` method calls has to be annotated. That is the point. You can put `noalloc` on a method that calls `stdlib`, or a library you cannot edit, and the guarantee still holds, because the compiler computes the allocation behavior from the code rather than from annotations the callees would have to carry. The un-annotated callee is not itself required to be allocation-free; it is free to allocate. It just cannot be reached from a `noalloc` method if it does.

The cost of this is that a `noalloc` method is coupled to code elsewhere. A change far away can break it. That is the feature working, and it is also a genuine drawback, covered below.

## Checked in release, not debug

The `noalloc` annotation is part of the signature and is always type-checked for conformance, in every build. Whether a method's body actually satisfies the annotation is verified only in release.

The verification runs on the optimized code, after inlining and after the heap-to-stack pass, and in a debug build those passes have not run. A release build keeps short-lived objects on the stack that a debug build leaves on the heap, so verifying a debug build would reject methods that allocate nothing in the artifact you actually ship. The guarantee is about the shipped binary, so it is checked against the shipped binary.

The consequence is that a `noalloc` method whose body allocates still compiles in a debug build, unverified, and fails only in release. Do not rely on `noalloc` holding while you develop at `-d`. It holds in the build you ship.

## After heap-to-stack

ponyc already has a pass that promotes a heap allocation to a stack allocation when it can prove the object does not escape (`genopt.cc`). Because the check runs after it, an allocation the pass moved to the stack passes. That is correct, not a loophole: an object on the stack is a stack allocation, and `noalloc` allows those. What it started as in the source does not matter; the check flags only allocation that survives off the stack.

## What the error says

Because the checking is non-local, the allocation that fails a `noalloc` method can be a long way from it, in code the author never opened. What the compiler can always report is the method that failed and the reason: that it, or something it calls, allocates.

Pointing further, at the specific allocation and the path down to it, would be far more useful, because "something under here allocates" is a place to start looking, not an answer. Whether that is possible is an open question; see the unresolved questions.

## Interfaces and traits

A method on an interface or trait can be marked `noalloc`. When it is, every implementer's version of that method must be `noalloc` as well.

```pony
interface Digestible
  fun \noalloc\ digest(): U64
```

Any type that provides `digest` for `Digestible` must provide it as `noalloc`. An implementer that allocates fails at its own definition, not at some distant call site that dispatches through `Digestible`:

```pony
class SlowDigest is Digestible
  fun \noalloc\ digest(): U64 =>
    let parts = recover Array[U64] end  // heap allocation
    // ...
```

`SlowDigest.digest` allocates, so it fails to compile at its own definition, with an error that says it implements a `noalloc` method but allocates.

This follows the same variance as `?`. Partiality can be widened away by an implementer: a trait method declared partial can be implemented by a total one, but not the reverse. `noalloc` is the strong end of the same kind of relationship. An implementer can be `noalloc` where the interface requires it, but it cannot be allocating, because that would weaken a guarantee callers depend on.

The reason this matters is virtual calls, below.

## Virtual calls

A call through an interface or trait resolves to a concrete method at runtime. Which one runs is not known at compile time, so the non-local check cannot trace it to a concrete body. Inside a `noalloc` method, a virtual call is only allowed when the interface or trait method it goes through is itself marked `noalloc`:

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

Because `Digestible.digest` is `noalloc`, every type that could be the runtime target has a `noalloc` `digest`, so the call is provably allocation-free no matter which one runs. A virtual call through a method that is not marked `noalloc` cannot be verified this way and is a compile error inside a `noalloc` method.

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

The test is manual: build a program and watch the compiler accept or reject it.

Write a program with a `noalloc` method whose body allocates, using a message send as the case, since a send clearly allocates. The release build has to fail. Then take the send out, leaving a `noalloc` method that does synchronous work and allocates nothing, and rebuild. Now the program has to compile.

The mechanism can also be checked directly: compile the failing program and confirm in the optimized IR that the allocation the check should flag, the message send's `pony_alloc_msg`, is present. That ties the test to the rule the check runs on, not just the pass/fail result.

That fail-then-pass pair is the core acceptance criterion. The same shape covers the harder parts of the design, each a small program that must build or must not: an allocation several calls down still fails; a virtual call through an unmarked interface fails while one through a `noalloc` interface passes; an implementer that allocates for a `noalloc` interface method fails at the implementer; and an allocation the heap-to-stack pass promotes to the stack still passes. All checked at release.

# Drawbacks

- **No signal in debug builds.** The body is verified only in release. While you develop at `-d`, a `noalloc` method that allocates compiles clean. You find the regression when you build release.

- **A `noalloc` method is coupled to the whole program.** Non-local checking means a change in distant code can break it, and the error surfaces at the annotated method rather than at the change. This is the same property that makes the feature useful, but it is a real cost: a `noalloc` method is not something you can fully reason about by reading it alone.

- **`noalloc` adds type-system surface.** It is a new signature property with variance and conformance rules on interfaces and traits. That is more to specify, implement, and teach than a feature that stays out of the type system.

- **Virtual calls are limited.** Inside a `noalloc` method, dispatch is only allowed through interface and trait methods that are themselves marked `noalloc`. Existing interfaces do not carry the mark, so using them in a `noalloc` method means marking them first.

- **What passes depends on the optimizer.** The check runs on the optimized artifact, so what satisfies it depends on what the heap-to-stack pass and the rest of the release pipeline remove. That is inherent to checking the code you actually ship, and it cuts both ways: you gain when the optimizer improves, and a change to the optimizer can change what compiles.

- **Implementation cost.** This needs a whole-program analysis that computes allocation behavior per method, run after optimization, plus the conformance checking for `noalloc` on interfaces and traits.

# Alternatives

**Local checking with required annotations.** Require every callee of a `noalloc` method to be declared `noalloc` too, and check each method only against its callees' declarations rather than their bodies. This gives local reasoning: a method can be understood from its own text, and a distant change cannot silently break it. It is rejected because it cannot do the main thing the motivation asks for. To mark a hot path that calls `stdlib`, every `stdlib` method on that path would have to be annotated first. You cannot protect a hot path built on code that has not opted in. Non-local checking does not need cooperation from the callees, and that is what lets the annotation go onto existing code.

# Unresolved questions

- **Can the error point to the actual allocation?** The compiler can always report that a `noalloc` method, or something it calls, allocates. Pointing at the specific allocation and the path to it would be far more useful, but the check runs on optimized code, after inlining and heap-to-stack have rearranged things, so how much of the original path and source location survives is unknown. This is for exploration.

- **What does the error report when more than one allocation caused the failure?** A `noalloc` method can allocate in several places at once, in its own body and across the code it reaches. Whether the error reports the first it finds, all of them, or just that the method allocates somewhere is open. It sits on top of the previous question: pointing at every allocation is harder than pointing at one, and pointing at one is already unsettled.

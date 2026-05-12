- Feature Name: type-layout-intrinsics
- Start Date: 2026-05-01
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Add a small, cohesive set of compiler intrinsics that expose the in-memory
layout of types: store size, array stride, alignment, and field offsets.
These are exposed as methods on a new `ABIMemoryLayout` primitive and are direct
projections of information LLVM already computes during code generation.

# Motivation

Pony users today have no first-class way to ask basic layout questions
about a type, oft required for C-FFI binding:

- "How many bytes do I need to allocate to hold one of these?"
- "How many bytes between consecutive elements in an array of these?"
- "What alignment does this type require?"
- "Where does field `_x` start within this struct?"

These questions come up every time a Pony program touches raw memory:
allocating buffers via `@pony_alloc`, packing or unpacking C-ABI
structs across the FFI boundary, building custom serializers, implementing
allocators, computing addresses for pointer arithmetic, or interfacing
with hardware/protocol layouts that pin field positions.

Today, users hand-compute these numbers, hard-code them, or copy them out
of C headers. All three approaches drift silently when fields are
reordered, types are widened, or the target ABI changes. The information
is already known to the compiler — there is no good reason for users to
recompute it by hand.

There is also a related family of questions about deep memory accounting
("how much memory does this `Array[String]` actually consume, transitively?").
Those are explicitly **out of scope** for this RFC; they will be proposed
separately as a separate interface.

Intrinsics in this RFC are the primitives that such a follow-up may choose
build upon.

# Detailed design

A new primitive `ABIMemoryLayout` is added to the standard library. It exposes
four methods, all `compile_intrinsic`. Each takes the type of interest as
a type parameter.

```pony
primitive ABIMemoryLayout
  fun tag size_of[T](): USize => compile_intrinsic
  fun tag stride_of[T](): USize => compile_intrinsic
  fun tag align_of[T](): USize => compile_intrinsic
  fun tag offsets_of[T](): Array[(String, USize)] val => compile_intrinsic
```

Each intrinsic maps to a specific LLVM query. Where two LLVM functions
both plausibly fit, the split below picks the one whose semantics match
the method's documented contract.

## `size_of[T]()`

The number of bytes occupied by the bits of a single value of type `T`,
not counting any padding required to place the next value in an array.
Equivalent to LLVM's `LLVMStoreSizeOfType`.

`T` must be a concrete nominal type (a numeric primitive, a struct, a
class, or an actor). It may not be a union, intersection, interface,
trait, or type parameter that does not resolve to a concrete type at
the call site — those are compile-time errors. For class and actor
types, `size_of` returns the full size of the heap-allocated object:
the runtime type-descriptor pointer (one `USize`-sized word on the
current target — eight bytes on 64-bit) plus the type's fields. This
is the size the runtime allocates for one instance, and the value
needed for packing classes or actors into a C-compatible structure.

To compute the size of a value whose static type is a union, match on
the value first to obtain a binding of the concrete member type, then
call `size_of` on that:

```pony
let bytes = match cell
  | let s: String => ABIMemoryLayout.size_of[String]()
  | let n: U64    => ABIMemoryLayout.size_of[U64]()
  end
```

The same pattern applies to `stride_of` and `align_of`.

**Example uses:**

Allocating a buffer to hold `n` packed values:

```pony
let buf = @pony_alloc(@pony_ctx(), (ABIMemoryLayout.size_of[Header]() * n))
```

Sanity-checking that an FFI-returned buffer is large enough before
casting:

```pony
if returned_bytes < ABIMemoryLayout.size_of[CSocketAddr]() then
  error
end
```

Computing the position of a trailing variable-length field in a serial
format:

```pony
let payload_offset = ABIMemoryLayout.size_of[FrameHeader]()
```

## `stride_of[T]()`

The number of bytes between the start of one element and the start of
the next when `T` is laid out in an array. Equivalent to LLVM's
`LLVMABISizeOfType`. Always greater than or equal to `size_of[T]()`;
they differ only when `T`'s alignment requires trailing padding.

This is the value that should be used whenever pointer arithmetic
walks element-by-element. Calling `size_of` instead would silently miss
the inter-element padding and produce a wrong address for any type
whose store size is not a multiple of its alignment.

**Example uses:**

Computing the address of element `i` in a manually managed contiguous
buffer:

```pony
let p_i = base.offset(ABIMemoryLayout.stride_of[Entry]() * i)
```

Sizing the backing allocation for an array-style data structure:

```pony
let bytes_needed = ABIMemoryLayout.stride_of[T]() * capacity
```

Passing element size to a C API that takes `(void*, element_size, count)`:

```pony
@write_array(buf, ABIMemoryLayout.stride_of[T](), n)
```

## `align_of[T]()`

The required alignment of `T` in bytes, as a power of two. Equivalent to
LLVM's `LLVMABIAlignmentOfType`.

**Example uses:**

Verifying that a pointer obtained from FFI is suitably aligned before
casting it to a typed pointer:

```pony
if (raw_ptr.usize() % ABIMemoryLayout.align_of[Header]()) != 0 then
  error  // misaligned; reading would be UB on strict-alignment targets
end
```

Implementing an arena/bump allocator that must round its cursor up to
the alignment of the type being placed:

```pony
fun ref _align_to[T](): USize =>
  let a = ABIMemoryLayout.align_of[T]()
  (_cursor + (a - 1)) and not (a - 1)
```

Confirming a buffer is suitable for SIMD or DMA, both of which often
require stricter alignment than the natural type alignment.

## `offsets_of[T]()`

Returns the complete field table of `T` as an immutable array of
`(name, byte_offset)` pairs, in declaration order. The compiler
synthesises this array per type at codegen time; callers iterate it
or look up a field by name.

`T` must be a struct, class, actor, or tuple. Unions, interfaces, and
traits are compile-time errors. For tuples, the names are the
positional accessor names (`"_1"`, `"_2"`, …) — the same names used
to access the fields in source code. For classes and actors, offsets
are measured from the start of the heap-allocated object — the same
anchor as `size_of` — so the type-descriptor pointer occupies the
first `USize`-sized word and user-declared fields begin after it.

The returned `Array[(String, USize)] val` is fully immutable and safe
to share. Both the array itself and the names inside it are `val`.
The compiler is free to deduplicate the table across call sites for
the same `T`; callers must not rely on identity.

**Example uses:**

Inspecting the layout of a type — for documentation, debugging, or
validating against a hand-derived expected layout for a C struct
binding:

```pony
for (name, off) in ABIMemoryLayout.offsets_of[Point]().values() do
  Debug("  " + name + " @ +" + off.string())
end
```

Iterating the table is the natural shape when the caller cares about
*every* field. Going further — copying every field into a buffer, say
— additionally needs per-field type information, which is out of scope
for this RFC (see "What these intrinsics do not do").

Looking up a single field by name (the typical `offsetof`-style use)
with a small helper:

```pony
fun _offset_of[T](name: String): (USize | None) =>
  for (n, off) in ABIMemoryLayout.offsets_of[T]().values() do
    if n == name then return off end
  end
  None
```

The helper returns `(USize | None)` rather than partial-erroring on a
missing name, so each caller chooses its own failure policy — error,
log, fall back to a default, or surface the absence in its own return
type.

Implementing an intrusive data structure (the Linux-kernel
`container_of` pattern), where a node embedded in a larger struct
recovers the address of its container:

```pony
fun container_of[Outer, Inner](inner_ptr: Pointer[Inner]): Pointer[Outer] ? =>
  let off = (_offset_of[Outer]("node") as USize).isize()
  inner_ptr.offset(-off)
```

Crossing an FFI boundary where the C side hands back a pointer to a
field, not the enclosing struct.

Why an array of pairs rather than a per-field accessor taking a
string? Pony has no first-class field references and no macro
system. An accessor like `offset_of[T](field: String)` would need
the compiler to special-case "argument must be a string literal" so
typos could be rejected at compile time; that is a new category of
intrinsic-argument handling. Exposing the whole table once and
letting users look up by name keeps the compiler change small and
uniform with the other three intrinsics, at the cost of moving the
"unknown field name" error from compile time to whatever the caller's
lookup helper does at runtime.

## What these intrinsics do not do

This RFC deliberately stops at the layout questions LLVM can answer
about a single type or value. It does not propose:

- **Deep memory accounting.** "How many bytes does this `Array[String]`
  transitively own?" needs traversal, sharing/cycle policy, and per-type
  semantics. A separate RFC will propose a `MemoryFootprint` interface
  that types opt into, implemented in terms of these intrinsics.
- **Actor heap introspection.** "How much has *this actor* allocated?"
- **Type names, descriptors, or other reflection.** Out of scope.

## Implementation

PR ponyc#5267 is a WIP for an example implementation for the purposes
of exploring this design-space.  Changes should only exist in the
compiler and stdlib.  No changes required to the runtime (libponyrt).

# How We Teach This

These intrinsics live alongside `Pointer.alloc` and the FFI machinery
in the user's mental model. They should be introduced in the section
of the language tutorial that already covers raw memory and FFI, with
worked examples for each of the use cases above. The
`size_of` / `stride_of` distinction will be the most novel concept
for users coming from C (where `sizeof` conflates the two), and is
explained below.

## The size / stride / alignment relationship

The mental model:

- **`align_of[T]`** is the rule. Every value of `T` must live at an
  address divisible by `align_of[T]`.
- **`size_of[T]`** is how much one value of `T` occupies under that
  rule.
- **`stride_of[T]`** is how far apart the rule forces consecutive
  elements to be in an array of `T`.

Stride must always be a multiple of alignment, so that every element's
start is aligned. The minimum legal stride is `size_of` rounded up to
the next multiple of `align_of`. For most types, size and stride are
equal — they diverge only when a type's content size isn't already a
multiple of its alignment. When they diverge, the gap is **trailing
padding**.

### Example: `(U64, U8)` — size 9, align 8, stride 16

Layout of a single value (9 bytes):

| `U64`           | `U8` |
|-----------------|------|
| 0 1 2 3 4 5 6 7 | 8    |

In an array, element 1 must start at a multiple of 8. Byte 9 isn't,
nor are 10..15. Byte 16 is. So elements are 16 bytes apart, and each
element's 16-byte slot has 7 bytes of trailing padding:

| `U64`           | `U8` | Padding              |
|-----------------|------|----------------------|
| 0 1 2 3 4 5 6 7 | 8    | 9 10 11 12 13 14 15  |

Subsequent elements occupy slots starting at byte 16, byte 32, byte
48, and so on, each laid out the same way relative to its slot start.

- `size_of` = 9 (a single value occupies 9 bytes)
- `stride_of` = 16 (the next value starts 16 bytes later)
- `align_of` = 8 (max alignment of any field — the `U64` needs 8-aligned)

The 7-byte trailing pad is what keeps each subsequent element's `U64`
8-aligned.

### Example: `(U32, U8)` vs `(U8, U32)` — same fields, different layouts

`(U32, U8)`: size 5, stride 8 — padding is trailing.

| `U32`   | `U8` | Padding |
|---------|------|---------|
| 0 1 2 3 | 4    | 5 6 7   |

`(U8, U32)`: size 8, stride 8 — padding is internal.

| `U8` | Padding | `U32`   |
|------|---------|---------|
| 0    | 1 2 3   | 4 5 6 7 |

Same fields, different order, same stride. `size_of` differs because
internal padding (between fields) counts toward size but trailing
padding does not. The visible consequence: a serializer that writes
`size_of[T]()` bytes per record writes 5 bytes for `(U32, U8)` but
8 bytes for `(U8, U32)`.

### Working out the layout by hand

Given a struct or tuple, you can derive size, stride, and alignment by
reading the fields left-to-right:

1. Start a cursor at byte 0.
2. For each field: advance the cursor to the next address divisible
   by that field's alignment (the gap is internal padding), then add
   the field's size.
3. After the last field, the cursor's position is `size_of`.
4. The whole type's `align_of` is the maximum alignment among its
   fields.
5. Round `size_of` up to a multiple of `align_of` — that's
   `stride_of`.

Worked example for `(U16, U64, U8)`:

1. Cursor at 0. `U16` (align 2) is already aligned. It occupies
   bytes 0..1. Cursor advances to 2.
2. `U64` (align 8): pad to byte 8 (6 bytes of internal padding).
   It occupies 8..15. Cursor advances to 16.
3. `U8` (align 1) is already aligned. It occupies byte 16. Cursor
   advances to 17.
4. `align_of` = max(2, 8, 1) = 8.
5. Round 17 up to a multiple of 8: 24.

So `size_of[(U16, U64, U8)]() == 17`,
`align_of[(U16, U64, U8)]() == 8`, and
`stride_of[(U16, U64, U8)]() == 24`.

### The footgun

For every primitive type in Pony (`U8`, `U16`, …, `U64`, `F32`,
`F64`), `size_of == stride_of`. Generic code that uses `size_of`
where it should use `stride_of` passes tests written against
primitives and silently misbehaves when instantiated with a tuple or
struct whose alignment forces trailing padding.

The rule of thumb: reach for `stride_of` whenever you are computing
positions in an array; reach for `size_of` only when you are packing
bytes into a format that has no inter-element padding (a wire format,
a tightly-packed file header, a record stream).

## Naming precedent

The naming follows established precedent: Swift's `MemoryLayout.size`
/ `.stride` / `.alignment`, and Rust's `mem::size_of` /
`mem::align_of` / `mem::offset_of!`. Pony users coming from either
language should find the names self-explanatory.

# How We Test This

Each intrinsic gets unit tests in the standard-library test suite
covering:

- Numeric primitives (`U8`, `U32`, `F64`, `I128`) — exact known sizes.
- Structs with mixed-alignment fields where `size_of` and `stride_of`
  must differ.
- Classes and actors — `offsets_of` returns the correct number of
  entries in declaration order, with offsets that are non-overlapping
  and respect alignment.
- Tuples — `offsets_of` uses `"_1"`, `"_2"`, … as the names.
- Negative tests: `size_of[SomeUnion]()`, `align_of[SomeInterface]()`,
  `offsets_of[SomeUnion]()` — all compile errors.

The LLVM functions these intrinsics wrap are exercised constantly by
LLVM's own backend; we do not need to test that LLVM is correct, only
that we are calling the right one. Standard CI coverage is sufficient.

# Drawbacks

- Adds four new compiler intrinsics, growing the intrinsic surface
  area the compiler must keep working as it evolves.
- The `size_of` / `stride_of` split is novel for C-trained users;
  picking the wrong one produces correct-looking code that breaks for
  types with trailing alignment padding.
- `offsets_of` returns a freshly-synthesised `Array val` per type
  used, growing the read-only data section of the binary by a small
  amount for each instantiated `T`. The cost scales with field count,
  not call sites (the compiler is free to deduplicate).
- Field-name lookups via `offsets_of` move the "unknown field name"
  error from compile time to runtime. Users who want compile-time
  protection must build it themselves (e.g. unit tests that exercise
  every lookup site).
- Exposing layout questions invites users to write code that depends
  on platform- or version-specific layouts. The intrinsics are
  inherently target-dependent (a struct's size on a 32-bit ABI may
  differ from a 64-bit ABI); users must understand they are getting
  the answer for the current target.

# Alternatives

**Expose only `size_of` and `align_of`; let users compute stride
themselves.** Stride is "round size up to alignment", which users could
compute. Rejected because the rounding rule is exactly the kind of
small, easy-to-get-subtly-wrong arithmetic that should live behind a
named primitive — and because "stride" is itself a load-bearing concept
in any code that walks an array.

**Use traits/interfaces instead of intrinsics.** A `Sized` trait that
each type implements would avoid touching the compiler. Rejected
because the values are properties of the type's layout, not behavior
the type chooses; making them virtual function calls would (a) impose a
runtime cost where there is none today and (b) let types lie about
their own size. The compiler is the source of truth.

**Put the methods on individual types instead of an `ABIMemoryLayout`
primitive** (e.g., `U32.size_of()`). Rejected because the method needs
to work with type parameters, not just concrete types named at the
call site, and because grouping all layout questions under one
namespace makes them discoverable as a family.

**Expose `offset_of[T](field: String): USize` instead of `offsets_of`.**
The original draft of this RFC took the C/Rust shape directly: a
per-field accessor whose `field` argument is required to be a string
literal so the compiler can reject typos at compile time. Rejected
because "intrinsic argument must be a string literal" is a new
category of compile-time validation that doesn't exist for any other
intrinsic today, and the team prefers to keep the compiler change
small and uniform. The `offsets_of` shape recovers the
single-field-lookup ergonomics with a five-line helper (see the
`_offset_of` example above) at the cost of moving "unknown field
name" detection to runtime.

Not implementing this RFC leaves Pony users hand-computing layout
numbers and copying them from C headers. The code keeps working until
something gets reordered or the target ABI changes, at which point it
silently breaks.

# Unresolved questions

None at this time.

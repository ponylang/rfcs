- Feature Name: range_redesign
- Start Date: 2026-10-14
- RFC PR:
- Pony Issue: https://github.com/ponylang/rfcs/issues/204

# Summary

`Range` and `Reverse` have accumulated enough problems that I think we should start over. This RFC removes `Reverse` entirely and replaces `Range` with a new design.

The new `Range` has two named constructors: `through` when you want the far end included, and `till` when you don't. Direction is figured out from the arguments — if `from` is bigger than `to`, it counts down. There are no negative steps and no separate class for going backwards. Invalid inputs produce empty ranges rather than errors. Infinite ranges are gone.

# Motivation

`Range` and `Reverse` have a bunch of problems:

- **Asymmetric APIs.** `Range` is half-open `[min, max)`; `Reverse` is closed `[max, min]`. Parameter order is different. `Range.next()` is partial; `Reverse.next()` isn't. `Range` has empty-range safety; `Reverse` doesn't.
- **Wrong parameter names.** The parameters are called `min` and `max`, but `Range[I64](10, -5, -1)` has `min = 10` and `max = -5`. The names don't match when the range descends.
- **Negative steps are a footgun.** `Range` defaults to `USize` and documents negative steps. `Range(10, 0, -1)` doesn't descend — `-1` as a `USize` is `USize.max_value()`. RFC #76 made this produce an empty range instead of an infinite one, but the API still suggests negative steps are meaningful for unsigned types.
- **Infinite ranges.** `Range[F64](0, F64.max_value() + F64.max_value(), 1)` iterates forever. `Reverse(10, 0, 0)` produces an infinite series of `10`. These are footguns in the common case, and a `while` loop handles the rare case where you actually want unbounded iteration.
- **Redundancy.** `Range` already handles descending for signed and float types. `Reverse` exists mostly for unsigned descending. A better `Range` can do that directly.

# Detailed design

## New API

```pony
class Range[A: (Real[A] val & Number) = USize] is Iterator[A]

  new through(from: A, to: A, step: A = 1)
    """
    Iterates from `from` through `to`, including both ends.

    `Range.through(1, 5)` produces `1, 2, 3, 4, 5`.
    `Range.through(5, 1)` produces `5, 4, 3, 2, 1`.

    Direction is inferred: ascending if `from < to`,
    descending if `from > to`. If `from == to`, produces
    a single value. Step is always a positive magnitude.

    Empty if `step <= 0`, or if any parameter is NaN or Inf.
    """

  new till(from: A, to: A, step: A = 1)
    """
    Iterates from `from` toward `to`, stopping before `to`.

    `Range.till(1, 5)` produces `1, 2, 3, 4`.
    `Range.till(5, 1)` produces `5, 4, 3, 2`.

    Direction is inferred: ascending if `from < to`,
    descending if `from > to`. If `from == to`, the range
    is empty. Step is always a positive magnitude.

    Empty if `step <= 0`, or if any parameter is NaN or Inf.
    """

  fun has_next(): Bool
  fun ref next(): A ?
  fun ref rewind()
```

## Design principles

- **Direction from arguments, not from the step.** If `from < to`, it goes up. If `from > to`, it goes down. Step is always positive — it gets added or subtracted based on direction. There's no negative step.
- **Constructor name tells you the boundary rule.** `through` includes the far end; `till` doesn't. I wanted to call it `until` but that's a reserved word in Pony (`repeat...until`), so `till` it is.
- **Invalid inputs produce empty ranges.** Step <= 0, NaN, and Inf aren't meaningful. I prototyped partial constructors that error on these, but it's worse — every call site needs a `try` block that also catches errors from the loop body, and `flat_map` silently drops segments when the lambda errors. Empty range on bad inputs is the lesser evil. See Alternatives for more.
- **No infinite ranges.** Infinite ranges are a footgun in the common case — you get one by accident and your program hangs. The rare case where you actually want unbounded iteration is easily handled with a `while` loop.

## Examples

```pony
// Ascending, exclusive far end (array indexing pattern)
for i in Range.till(0, 10) do
  env.out.print(i.string())  // 0, 1, 2, ..., 9
end

// Ascending, inclusive far end
for i in Range.through(1, 10) do
  env.out.print(i.string())  // 1, 2, 3, ..., 10
end

// Descending with USize — no negative step needed
for i in Range.through(10, 1) do
  env.out.print(i.string())  // 10, 9, 8, ..., 1
end

// Descending to zero (inclusive)
for i in Range.through(5, 0) do
  env.out.print(i.string())  // 5, 4, 3, 2, 1, 0
end

// Descending with a step
for i in Range.through(10, 0, 2) do
  env.out.print(i.string())  // 10, 8, 6, 4, 2, 0
end

// Descending, exclusive far end
for i in Range.till(10, 0) do
  env.out.print(i.string())  // 10, 9, 8, ..., 1
end

// Float with fractional step
for x in Range.till(0.0, 1.0, 0.25) do
  env.out.print(x.string())  // 0.0, 0.25, 0.5, 0.75
end

// Signed descending
for i in Range[I64].through(5, -5) do
  env.out.print(i.string())  // 5, 4, 3, ..., -5
end

// Single element
for i in Range.through(7, 7) do
  env.out.print(i.string())  // 7
end

// Empty range
Range.till(5, 5)  // empty: from == to with exclusive far end
```

## Implementation

See [PR #6291](https://github.com/ponylang/ponyc/pull/6291) for the full implementation. The interesting bit is `has_next()` — it does a double-bound check that handles both the normal "did we reach the end" case and integer overflow/underflow. When a `USize` underflows past zero it wraps to `USize.max_value()`, which fails the `_idx <= _from` check. So `Range[USize].through(5, 0)` just works — produces `5, 4, 3, 2, 1, 0` and stops.

## What is removed

- `Reverse` — gone entirely.
- `Range.create` — no default constructor. You pick `through` or `till`.
- `Range.is_infinite()` — no infinite ranges, so no need for this.
- `Range.is_empty()` — `has_next()` covers this.

# How We Teach This

Docstrings on `through` and `till` have examples. Call it out in release notes with migration examples.

Updates needed in pony-patterns:

- `docs/async/batch-and-yield.md` — 4 `Range` calls
- `docs/async/access.md` — 1 `Range` call
- `docs/object-capabilities/single-use.md` — 2 `Range` calls

# How We Test This

Existing `Range` and `Reverse` tests are replaced. See [PR #6291](https://github.com/ponylang/ponyc/pull/6291) for the full suite. Covers both constructors in both directions across `USize`, signed, and float types, plus overflow/underflow safety, invalid inputs, and the usual edge cases.

# Drawbacks

This breaks everything. Every `Range` and `Reverse` call site has to change. `Range` is one of the most used types in the stdlib and user code.

`Range(0, 10)` doesn't work anymore — users have to pick `through` or `till` every time. More verbose, but they always know what they're getting.

# Alternatives

I considered a few other approaches and rejected them: adding a `Range.reverse` constructor while keeping the existing API, fixing `Reverse`'s safety gaps without merging it, keeping `create` as an alias for `till`, and doing nothing.

I also prototyped partial constructors that error on bad inputs. They're worse. Every call site in a non-partial context needs a `try` block, and that `try` also catches errors from the loop body — silently swallowing errors that should propagate. And lambdas that construct a Range inside `flat_map` have to be partial, which means `flat_map` silently drops segments when the lambda errors. Both of those are new silent-failure modes that didn't exist before. Empty ranges on bad inputs aren't great, but they're the lesser evil.

# Unresolved questions

None at this time.

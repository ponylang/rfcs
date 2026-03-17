- Feature Name: shuffle_test_ordering
- Start Date: 2026-03-16
- RFC PR:
- Pony Issue:

# Summary

Add a `--shuffle` option to PonyTest that randomizes test execution order, with an optional seed for reproducibility.

# Motivation

PonyTest's `--sequential` flag is mostly used to prevent flaky tests in constrained CI environments where tests have timeouts and would otherwise compete for CPU time. The problem is that sequential mode runs tests in a fixed registration order every time. This hides test coupling: test B might only pass because test A ran first and left behind some state. You won't find out until someone reorders the tests or removes test A, and then something breaks in a way that's hard to trace back to the real cause.

Concurrent mode has a version of the same problem. Execution order is non-deterministic due to actor scheduling, but the start order is deterministic: tests are dispatched to their groups in registration order. Exclusion groups run tests sequentially within the group, again in registration order. Any of these fixed orderings can mask coupling.

Shuffling test order is a well-established technique for catching these problems. Frameworks like pytest (via pytest-randomly) and RSpec (`--order random`) have had this for years. The idea is simple: if your tests pass in a random order, they're actually independent. If they don't, you've found a bug before it finds you.

# Detailed design

## Command line interface

PonyTest gets a new `--shuffle` option that accepts an optional U64 seed:

```
--shuffle          Shuffle test order using a random seed
--shuffle=SEED     Shuffle test order using the given U64 seed
```

When you use `--shuffle` without a seed, PonyTest generates one from `Time.cycles()`. Either way, the seed is printed before any test output:

```
Test seed: 8675309
```

That seed is everything you need to reproduce a failure. Grab it from the CI log, pass it back with `--shuffle=8675309`, and you get the exact same test ordering.

Without `--shuffle`, nothing changes. No seed is printed, tests run in the same order they always have.

## What gets shuffled

Shuffle applies to all scheduling modes:

- **Sequential mode** (`--sequential --shuffle`): The single-file execution order is randomized. This is the primary use case: you're already running sequentially to avoid CI flakiness, and now you also catch test coupling.
- **Concurrent mode** (`--shuffle`): The order in which tests are dispatched to the simultaneous group is randomized. Actor scheduling makes actual execution order non-deterministic regardless, but this changes which tests *start* in which relative order.
- **Exclusion groups** (`--shuffle`): Tests within each exclusion group are shuffled independently. Exclusion groups run their tests sequentially, so they have the same fixed-ordering problem as `--sequential`.

All shuffling is derived from a single seed, so reproducing a failure only requires one value.

## Implementation

### Argument parsing

PonyTest rolls its own argument parsing in `_process_opts()` to avoid depending on the options package. The new flag follows the existing pattern:

```pony
elseif arg == "--shuffle" then
  _shuffle = true
elseif arg.compare_sub("--shuffle=", 10) is Equal then
  _shuffle = true
  try
    _shuffle_seed = arg.substring(10).u64()?
  else
    _env.out.print("Invalid shuffle seed: " + arg.substring(10))
    _do_nothing = true
    return
  end
```

This requires two new fields on `PonyTest`:

```pony
var _shuffle: Bool = false
var _shuffle_seed: U64 = 0
```

And a new line in the help text:

```
--shuffle[=seed]  - Shuffle test execution order. Optionally specify a U64 seed.
```

### Buffered dispatch

Today, `PonyTest.apply()` creates a `_TestRunner` and dispatches it to its group immediately. The group is what actually starts the test running via `runner.run()`. You can't shuffle a list you haven't finished building yet, so dispatch has to be deferred. But runner creation doesn't need to be: `_TestRunner` just stores its fields on construction, it doesn't start running until the group tells it to.

So `apply()` still creates runners eagerly (consuming the `iso` test), but instead of dispatching to the group, it pushes `(_TestRunner, _Group)` pairs onto a buffer:

```pony
embed _pending: Array[(_TestRunner, _Group)] =
  Array[(_TestRunner, _Group)]
```

The `_all_tests_applied()` behavior already runs after all tests are registered, so it becomes the dispatch point. If `_shuffle` is true, it shuffles `_pending` before dispatching. If false, it dispatches in registration order, same as today.

### Shuffle algorithm

We use Pony's `Rand` (`XorOshiro128Plus`), seeded via `from_u64` which uses SplitMix64 to expand a single U64 into the two state values the PRNG needs. If no seed was provided, one is generated from `Time.cycles()` and stored back into `_shuffle_seed` for printing.

`Time.cycles()` reads the CPU cycle counter (RDTSC on x86, platform-specific equivalents elsewhere). The Pony runtime itself uses the same underlying mechanism to seed its systematic testing PRNG. It's a better seed source than wall clock time: higher resolution, not subject to the platform-dependent granularity issues that make `Time.nanos()` return the same value for runs that start close together.

The `Random` trait already has a `shuffle` method that implements Fisher-Yates, so there's no reason to reimplement it.

```pony
use "random"
use "time"

// In _all_tests_applied(), before dispatch:
if _shuffle then
  if _shuffle_seed == 0 then
    _shuffle_seed = Time.cycles()
  end
  _env.out.print("Test seed: " + _shuffle_seed.string())

  let rand = Rand.from_u64(_shuffle_seed)
  rand.shuffle[(_TestRunner, _Group)](_pending)
end
```

After shuffling (or not), dispatch is straightforward:

```pony
for (runner, group) in _pending.values() do
  group(runner)
end
```

### Exclusion group shuffling

Because tests are buffered and shuffled before being dispatched to groups, the order they arrive at each group is already shuffled. `_ExclusiveGroup` runs tests in arrival order, so no changes are needed to the group implementations. The single shuffle of `_pending` naturally randomizes within every group.

### Seed value of 0

A seed of 0 is valid. The "generate a random seed" path is triggered by the absence of `=SEED` in the argument, not by the seed value being 0. The implementation should use a separate boolean or `(U64 | None)` to distinguish "no seed provided" from "seed is 0". The sketch above uses a simple `_shuffle_seed == 0` check for brevity, but the actual implementation should handle this correctly.

# How We Teach This

The PonyTest package docstring already documents `--sequential` and should cover `--shuffle` in the same place, following the same pattern. The two options complement each other: `--sequential` prevents CI flakiness from concurrent resource contention, and `--shuffle` prevents the false confidence that comes from always running tests in the same order. For CI environments that need sequential execution, `--sequential --shuffle` is the recommended combination. You get stable runs without resource contention, and each CI run uses a different seed, so test coupling surfaces over time instead of hiding forever.

The documentation should cover seed-based reproducibility: when a shuffled run fails, the seed printed at the top of the output is all you need to reproduce the ordering. No changes to the Pony tutorial are needed.

# How We Test This

The core property to verify is deterministic reproducibility: given the same seed, the same tests run in the same order every time. Beyond that:

1. **Shuffle changes order**: With a seed known to produce a different order than registration order, verify it does.
2. **Seed reproducibility**: Same seed, same tests, same order. Twice.
3. **Different seeds, different orders**: Two different seeds produce different orderings. With enough tests, collision probability is negligible.
4. **Seed output**: Printed when `--shuffle` is active, absent when it isn't.
5. **Sequential interaction**: `--shuffle --sequential` produces a shuffled sequential run.
6. **Exclusion groups**: Tests within an exclusion group get reordered when `--shuffle` is active.
7. **Default behavior preserved**: Without `--shuffle`, registration-order dispatch is unchanged.

PonyTest's tests live in the ponyc repo and run via `make test`. Existing CI coverage handles this.

# Drawbacks

Buffered dispatch changes PonyTest's architecture. Today, tests are dispatched as they arrive. With this change, they're always collected first and dispatched in a batch. This means every test object lives in memory until all tests are registered, and the first test starts slightly later. No test suite large enough to care about this exists in practice, but it is a change in behavior.

# Alternatives

**Shuffle only in sequential mode.** We could limit shuffling to `--sequential` since that's where the fixed-ordering problem is most acute. However, exclusion groups have the same problem, and even concurrent start order can matter. Shuffling everywhere is more thorough and the implementation cost is the same.

**Separate `--seed` flag.** We considered `--shuffle` plus a separate `--seed=N` flag. This was rejected because a seed without shuffle is meaningless, and combining them into one flag (`--shuffle[=SEED]`) is simpler for users.

**External shuffling.** Users could shuffle test ordering by writing a custom `TestList` that randomizes. This puts the burden on every test author, doesn't provide reproducibility infrastructure, and doesn't help with the majority of existing test suites that use straightforward registration.

**Do nothing.** The status quo works. Test coupling is a real problem, but it's not a new one.

# Unresolved questions

- Should `--shuffle` interact with `--list`? Currently `--list` prints test names in registration order without running them. It might be useful to print the shuffled order so you can verify what ordering a given seed produces. On the other hand, `--list` is about discovering what tests exist, not how they'll run.
- The exact output format for the seed line ("Test seed: N") could be adjusted during implementation if there's a better format that's easier to parse programmatically.

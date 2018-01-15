- Feature Name: improved-ponybench
- Start Date: 2018-01-15
- RFC PR:
- Pony Issue:

# Summary

The contents of this RFC will present concerns with the current implementation of ponybench and provide an upgrade path based on a working prototype at https://github.com/Theodus/pony-benchmark.

# Motivation

Ponybench, in its current form, has flaws that make it unusable in some cases:
- Benchmark functions cannot be garbage collected.
- The user has no way to specify actions that should occur for setup or tear-down.
- Asynchronous benchmarks have a tendency to move to other threads due to the use of Promises, leading to high deviation in the results.

The new version of ponybench will address these concerns. New functionality will also be added to produce statistics from samples and to output the sample data in CSV format so that users may further analyze the data collected.

# Detailed design

The API for the `PonyBench` actor and the `MicroBenchmark` interface will resemble that of `PonyTest` and `UnitTest`, respectively. They will be defined as follows:

```pony
actor PonyBench
  """
  PonyBench provides a microbenchmarking framework for synchronous and
  asynchronous operations listed by a `BenchmarkList`.
  """

  new create(env: Env, list: BenchmarkList)

  be apply(bench: Benchmark)

interface tag BenchmarkList
  fun tag benchmarks(bench: PonyBench)

type Benchmark is (MicroBenchmark | AsyncMicroBenchmark)
  """
  A benchmark defines the operation that will be run repeatedly to measure its
  runtime over multiple samples. Each sample will run the `apply` method
  repeatedly to minimize noise that may be observed from single runs. Setup and
  teardown necessary for the microbenchmark may be defined in the `before` and
  `after` methods. These operations will not be measured.

  Asynchronous microbenchmark `apply`, `before`, and `after` methods are given a
  continuation to signal to ponybench that it may resume when its `continue`
  method is called.
  """

trait iso MicroBenchmark
  fun box name(): String
  fun box config(): BenchConfig => BenchConfig
  fun box overhead(): MicroBenchmark^ => OverheadBenchmark
  fun ref before() => None
  fun ref apply() ?
  fun ref after() => None

trait iso AsyncMicroBenchmark
  fun box name(): String
  fun box config(): BenchConfig => BenchConfig
  fun box overhead(): AsyncMicroBenchmark^ => AsyncOverheadBenchmark
  fun ref before(c: AsyncBenchContinue) => c.complete()
  fun ref apply(c: AsyncBenchContinue) ?
  fun ref after(c: AsyncBenchContinue) => c.complete()

class val BenchConfig
  """
  - samples: The amount of times each microbenchmark is measured
  - max_iterations: The maximum amount of iterations per sample
  - max_sample_time: The maximum time (in nanoseconds) to measure each sample
  """
  let samples: USize
  let max_iterations: U64
  let max_sample_time: U64

  new val create(
    samples': USize = 20,
    max_iterations': U64 = 1_000_000_000,
    max_sample_time': U64 = 100_000_000)

```

Implementation Details:
- Each microbenchmark is measured with recursive behaviors of a single actor to minimize runtime overhead while allowing garbage produced by the benchmarks to be collected. The `AsyncBenchContinue` class is used to signal continuations for asynchronous microbenchmarks without involving another actor, such as `Promise`.
- `pony_triggergc` will be called before each sample is measured, after the setup for the benchmark has completed.
- Measurements will be taken with the time package's `Time.nanos` with `Time.perf_begin` and `Time.perf_end` to prevent instructions leaking outside of the start and end measurements for each sample.

The implementation of this is at https://github.com/Theodus/pony-benchmark/blob/master/_runner.pony

# How We Teach This

A "tools" section of the tutorial should be added as an extension of the documentation. This may include examples of how ponybench may be used to produce and visualize the data collected with examples such as these (though they should be produced with an open-source tool, not MATLAB):

![alt text](https://github.com/Theodus/pony-benchmark/raw/master/examples/custom-config/charts/box.jpg)

![alt text](https://github.com/Theodus/pony-benchmark/raw/master/examples/custom-config/charts/hist.jpg)

# Drawbacks

- Breaks existing code using ponybench

# Alternatives

# Unresolved questions

- Feature Name: ponybench
- Start Date: 2016-06-04
- RFC PR: 
- Pony Issue: 

# Summary

Ponybench provides a microbenchmarking facility that can be used to examine the performance of pony code. This gives users an opportunity to easily profile their programs, remove bottlenecks, and make them faster.

# Motivation

This package adds to the tooling around pony. Good tools support the language ecosystem and increase adoption.

# Detailed design

The API of this package is similar to that of ponytest for ease of use. The following is an example of a comlete program with 2 trivial benchmarks:

```pony

actor Main is BenchmarkList
  new create(env: Env) =>
    PonyBench(env, this)

  fun tag benchmarks(bench: PonyBench) =>
    bench(_BenchmarkAdd)
    bench(_BenchmarkSub)

class iso _BenchmarkAdd is Benchmark
  fun name(): String => "addition"

  fun apply(b: BenchmarkRunner) =>
    let n1: USize = 2
    let n2: USize = 2
    for i in Range[USize](0, b.n()) do
      b.discard(n1 + n2)
    end

class iso _BenchmarkSub is Benchmark
  fun name(): String => "subtraction"

  fun apply(b: BenchmarkRunner) =>
    let n1: USize = 4
    let n2: USize = 2
    for i in Range[USize](0, b.n()) do
      b.discard(n1 - n2)
    end

```

The current proof of concept implentation can be found at [https://github.com/Theodus/ponybench](https://github.com/Theodus/ponybench)

# How We Teach This

Example use of the package should be included in the pony tutorial as well as the package docs, similar to ponytest.

# Drawbacks

None.

# Alternatives

None.

# Unresolved questions

- Should this be part of the current ponytest package?
- How may ponybench benchmark memory allocations?

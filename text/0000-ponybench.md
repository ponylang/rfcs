- Feature Name: ponybench
- Start Date: 2016-06-04
- RFC PR: 
- Pony Issue: 

# Summary

Ponybench provides a microbenchmarking facility that can be used to examine the performance of pony code. This gives users an opportunity to easily profile their programs, remove bottlenecks, and make them faster.

# Motivation

This package adds to the tooling around pony. Good tools support the language ecosystem and increase adoption.

# Detailed design

The PonyBench.apply behavior has the following signature:
```pony
be apply[A: Any #share](name: String, f: {(): A ?} val, ops: U64 = 0)
```
The amount of ops may be set manually, but by default it is handled automatically with the benchmark run for a minimum of 1 second by default. If the second has not elapsed when the Benchmark function returns, the amount of ops is increased in the sequence 1, 2, 5, 10, 20, 50, … and the function is run again. A simple average (total execution time over ops) is used to calculate the execution time in nanoseconds.

```pony
actor Main
  new create(env: Env) =>
    let bench = PonyBench(env)
    bench[USize]("fib 5", lambda(): USize => Fib(5) end)
    bench[USize]("fib 10", lambda(): USize => Fib(10) end)
    bench[USize]("fib 20", lambda(): USize => Fib(20) end)
    bench[USize]("fib 40", lambda(): USize => Fib(40) end)
    bench[String]("fail", lambda(): String ? => error end)
    bench[USize]("add", lambda(): USize => 1 + 2 end, 1_000_000)
    bench[USize]("sub", lambda(): USize => 2 - 1 end, 1_000_000)

primitive Fib
  fun apply(n: USize): USize =>
    if n < 2 then
      n
    else
      apply(n-1) + apply(n-2)
    end

```
Output:
```
fib 5     50000000          33 ns/op
fib 10     5000000         352 ns/op
fib 20       30000       42951 ns/op
fib 40           2   646773866 ns/op
**** FAILED Benchmark: fail
add        1000000           2 ns/op
sub        1000000           2 ns/op
```
For example, this shows that the add function was executed 1,000,000 times and took an average of 2 ns/op).

There will also be an async behavior as follows:
```pony
be async[A: Any #share](name: String, f: {(): Promise[A] ?} val, ops: U64 = 0)
```
which will calculate the average time until the Promise is fulfilled.

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

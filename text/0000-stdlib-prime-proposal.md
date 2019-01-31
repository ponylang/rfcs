- Feature Name: stdlib-prime-proposal
- Start Date: 2019-01-31
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Add some prime maths to the standard library, within the `math` package: primality and coprimality tests, prime factorization, prime iteration and GCD/LCM.

# Motivation

As the standard library entry for the `math` package states, this package needs to be populated with functionalities.
My proposal would be to have prime utilities added to it, as I believe it would fit nicely with the current `fibonacci` class.

There are many potential use cases, they show a lot of interesting characteristics, like their chaotic patterns.
This feature may also be used for benchmarking, to show how fast Pony crunches down numbers into other numbers.

# Detailed design

A draft/proposal of the feature is up at [pony-primes](https://github.com/adri326/pony-primes).
Most of the features will be contained in a `Prime` primitive, with the only exception of the prime iterator, which has its own class, `PrimeIterator`.

The methods and class will have generics, to allow the user to choose what type they want to be working with. `USize` is the default type for these generics.

## `primitive Prime`

Here is a list of the as-of-today methods contained in the `Prime` primitive proposal on `pony-primes`, which would ultimately find their way in the `sdlib`.

* `is_prime(num)`: the most straightforward method, it returns a `Bool`, stating wether or not the number is prime:
This method uses the property that all of the primes, with the exception of `2` and `3`, are of the form `6n ± 1` (with `n ∈ ℕ`).
```pony
fun is_prime[A: (Integer[A] val & Unsigned) = USize](num: A): Bool
```
**Usage:**
```pony
env.out.print(Prime.is_prime(3).string()) // true
env.out.print(Prime.is_prime(257).string()) // true
env.out.print(Prime.is_prime(24).string()) // false
```
* `is_coprime(a, b)`: returns a `Bool`, stating wether or not `a` and `b` are coprime - if they do not share any prime factors. It uses the property that `a` and `b` are coprime if and only if `gcd(a, b) == 1`.
```pony
fun is_coprime[A: (Integer[A] val & Unsigned) = USize](a: A, b: A): Bool
```
**Usage:**
```pony
env.out.print(Prime.is_coprime(3, 5).string()) // true
env.out.print(Prime.is_coprime(24, 35).string()) // true
env.out.print(Prime.is_coprime(5, 95).string()) // false, they both are multiples of 5
```
* `gcd(a, b)`: returns the [greatest common divisor](https://en.wikipedia.org/wiki/Greatest_common_divisor) of `a` and `b`, used by `is_coprime`.
```pony
fun gcd[A: (Integer[A] val & Unsigned) = USize](a: A, b: A): A
```
**Usage:**
```pony
env.out.print(Prime.gcd(3, 6)) // 3
env.out.print(Prime.gcd(4, 7)) // 1
```
* `lcm(a, b)`: returns the least common multiplier of `a` and `b` ~~so that `gcd` doesn't feel lonely~~
```pony
fun lcm[A: (Integer[A] val & Unsigned) = USize](a: A, b: A): A
```
**Usage:**
```pony
env.out.print(Prime.lcm(3, 6)) // 6
env.out.print(Prime.lcm(4, 7)) // 28
```
* `next_prime(num)`: returns the prime following `num` (not `num` itself if it is prime). This function currently uses the code from `PrimeIterator`.
```pony
fun next_prime[A: (Integer[A] val & Unsigned) = USize](num: A): A
```
**Usage:**
```pony
env.out.print(Prime.next_prime(10)) // 11
env.out.print(Prime.next_prime(10000)) // 10007
```
* `prime_factors(num)`: the most interesting method in my opinion. It returns as an `Array` all the prime factors of a number.
This method iterates using the `PrimeIterator`, and does not pack reoccurring prime factors into powers of these (this means that `primes_factors(24)` will output `[2; 2; 2; 3]`).
```pony
fun prime_factors[A: (Integer[A] val & Unsigned) = USize](num: A): Array[A] ref
```
**Usage:**
```pony
env.out.print("24 = " + " * ".join(
  Prime.prime_factors(24).values())
) // 24 = 2 * 2 * 2 * 3
```

## `class PrimeIterator`

This class is an `Iterator` listing the prime numbers from `1` or a given number to a limit (by default the maximum value).
The prime following the limit will be included in the Iterator's values.

* `new create(limit)`: creates a `PrimeIterator`, the `limit` being by default the maximum value of the type
* `new start_at(last, limit)`: creates a `PrimeIterator`, with the given starting value (`last`)
* `has_next()`: tells if the last prime number spitted out is below the limit
* `next()`: gives you the next prime number

**Usage:**

```pony
// prints all the prime numbers from 1 to 100
for prime in PrimeIterator do
  env.out.print(prime.string())
end
// will output:
// 2
// 3
// ...
// 101
```

# How We Teach This

As this utilities will be in the `math` package for the standard library, their explanations should be done within the `stdlib` documentation.

Mathematical yet easy to understand and to apprehend terminology should be used.
Words like `coprimes`, `gcm` and `lcm` could have links to articles explaining them.

If a tutorial for the `math` package comes up, this feature could be introduced or evoqued, but I do not feel there is a need to.

# How We Test This

Unit testing can easily be implemented: a good part of them can already be found in the `/test` directory of [pony-primes](https://github.com/adri326/pony-primes).

The algorithms used here are common and so can easily be fixed if they happen to break.

None of the code here have an impact on the other parts of the stdlib and only the `builtin` library is used.

# Drawbacks

This code would sit next to fibonacci's code and should not require much maintenance (the fibonacci code hasn't been updated in 2 years).

However, this feature is not important an important one, and only implements common algorithms which are rarely implemented in other languages' standard library.
It could thus find a better home in `main.actor`.

# Alternatives

As stated above, this feature could be redirected to `main.actor`, or even stay where it currently is - in its own repository.

# Unresolved questions

* Should the currently-used generics be improved?
* The design of the `PrimeIterator` might need to be reviewed, regarding in particular the idea of having it spit out the prime following the last value or not

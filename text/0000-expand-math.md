- Feature Name: Expand `math`
- Start Date: 2020-07-05
- RFC PR:
- Pony Issue:

# Summary

This RFC proposes expanding the standard library's `math` package and the shape it might take to leverage the full extent of Pony.

# Motivation

Currently, `math` includes only a `Fibonacci` class. This should be expanded to include math types, constants, and present a structure with further expansion in mind. An expanded `math` library will allow a unified mathematics among Pony developers.

# Detailed design

The primary goals of this initial expansion are: 1) (re)structure the library into distinct sub-packages and 2) provide common `math` data types.

Subpackaging and explicit name spacing is intended to divide concerns rather than have one large `math` library.

## Structure

I propose a structure of distinct subpackages including the following:

+ `math/big`: Arbitrary precision numbers
+ `math/series`: Mathematical series
+ `math/constant`: Mathematical constants
+ `math/rational`: `Rational` data type and related functions
+ `math/complex`: `Complex` data type and related functions
+ `math/(x,exp,etc)`: experimental additions, utilities, and effective "catch-all" for matters that do not neatly fit into other subpackages

## Common Data Types

As previewed above in [Structure](#structure), expanding the `math` package should include implementations of common mathematics data types. Below are some implementation proposals for those data types.

### `math/big`

Should include `BigInt` and `BigFloat`.

### `math/series`

`math/series` should include a `Series` interface which is a superclass of `Iterator`. The purpose of creating a new abstract data type is to generalize functions over mathematical series which do not make sense over iterators -- such as whether a `Series` is diverging or converging, a property that is all but meaningless for an `Iterator`.

Example series include `Fibonacci` (already exists), `Pascal` (nCk), `Triangular` ({n+1}C{2}), `Square` (n^2), `Pentagonal` ({2n * (2n - 1)} / 2), etc.

### `math/constant`

Initial values to include are those with underlying LLVM representations from the [number namespace](https://llvm.org/doxygen/namespacellvm_1_1numbers.html).

Once these values exist in `math/constant`, they should be removed from where they are now, which is on `F32` and `F64` of [`Float`](https://github.com/ponylang/ponyc/blob/master/packages/builtin/float.pony).

I foresee this as a primitive `Constant` with methods for each value (e.g., `Constant.pi[A: Float](): A`).

### `math/rational`

`math/rational` should decide backing precision on `create[A: Real]` and return precision on `apply][B: Number]` -- `let x = Rational.create[U64](where numerator=2)` gives a type which is represented by `U64`/`U64` and starts with a value of `2`/`1` which can then be returned via `x.apply[F32](): F32 => F32(2) / F32(1)`. `Rational` should be parameterized only on `Real` types and track sign via an embedded field.

Changing the underlying precision "in-place" is done via a `prec[C: Real]()` method which creates a new instance of the value with a different precision.

(I see this package as subsuming `Decimal` and `Fractional` types, as was previously discussed in Zulip.)

### `math/complex`

`Complex` should follow similar to `math/rational` in that it is parameterized on `Real` types which are used to represent both the real and imaginary part of the number -- `let x = Complex[U128](7, 2)` is `7 + 2i`.

Changing the underlying precision is done via a `prec[C: Real]()` method which creates a new instance of the value with a different precision.

### `math/(x,exp,etc)`

The name is subject to change and I want comments on what such a "catch all" package should be named to clearly denote it is for matters which do not neatly fit elsewhere in my proposed subpackages.

The explicit intention of this subpackage is to gather useful matters that do not fit into another more dedicated packages. Examples of matters that would be included here are trigonometry and linear algebra functions before corresponding `math/trig` and `math/la` packaged are made.

# How We Teach This

I am not familiar with existing materials on Pony numeric types before their introduction in the Tutorial. Given this RFC concerns expanding Pony math types to those commonly seen elsewhere I am unsure any special teaching materials are needed on the matter. Ample documentation and usage examples within the expanded `math` library should be sufficient.

A new chapter could be added as Tutorial > Packages > Math which walks through the layout and standard usage of Pony `math` in the context of Pony.

# How We Test This

I recommend use of `ponycheck` to test all reversible operations pairs (`x+y-y == x`, `x*y/y == x`, etc), precision persistence (`Rational[U8](where numerator=x, denominator=y) * y == x`), and overflow/underflow protection (`Rational[U8](255, 1) + 1 => error`).

Testing `math` should not affect any other parts of Pony and as such standard CI should suffice.

# Drawbacks

The major drawback is additional maintenance cost as well as immediate and continued disagreement around implementation and feature details.

# Alternatives

Prior discussion on the expansion of `math` occurred on Zulip [contribute to Pony > math lib](https://ponylang.zulipchat.com/#narrow/stream/192795-contribute-to.20Pony/topic/math.20lib).

The amount of subpackages is a lot and could be reduced down to one single `math` package if we so choose as none of the proposed additions clash at this time.

# Unresolved questions

+ How expansive should the `math` library become (whether that is one package or multiple subpackages)?
+ Does having `Rational` mean `Decimal` and/or `Fractional` types are not needed at the moment?

---

My personal opinion is that the standard `math` library, in any form, should only include elements of no opinion. That is to say, a `Rational` is numerator over denominator and any implementation reduces down to that form, meanwhile a `Graph` type could be backed by: adjacency list, adjacency matrix, or incidence matrix, and given there are multiple options is better left out of the standard library in favor of community implementations.

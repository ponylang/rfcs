- Feature Name: Introduction of empty Ranges
- Start Date: 2022-05-29
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

The RFC addresses the fact that for certain parameters, Pony currently creates infinite Range iterators that produce infinite numbers of values that lie *outside* the range of values `min` and `max` provided to `Range`. For example the Range iterator `Range(10, 0)` produces the infinite sequence `10, 11, 12, ..` on subsequent calls to `.next()` where all but the first element do not lie within the range 10..0. However, it is argued here that an iterator using the name `Range` can be expected to produce a sequence of values that lie within the `min, max` bounds. This expectation can be met by introducing and in such and similar cases returning *empty* ranges. One unexpected side effect of Pony's current behavior is that even though finite bounds are given, an *infinite* iterator can be created from them which, when used without consideration for this side effect, can produce indefinitely-running actors and "hanging" programs.
The RFC proposes a delineation of the so-far *infinite* cases into one of two types: those at are now *empty*, and those which remain *infinite* even under this RFC.

# Motivation

Currently, a Range is considered infinite if either 1) the `step` is `0`, or any of `min`, `max`, or `step` are `NaN`, `+Inf` or `-Inf`, or 2) if no progress can be made from `min` to `max` due to the sign of the `step`.

In this RFC it will be argued that 1) is too broad in that it creates infinite iterators that should be *empty*, and that 2) should be entirely carved out from the set of currently *infinite* iterators all of which should also instead be *empty*. Currently, the following code fragment

```pony
  let r =  Range[I32](0, 10, -1)
  for i in Range(0, 10) do
    try env.out.print(r.next()?.string()) end
  end
```

produces

```
0
-1
-2
-3
-4
-5
-6
-7
-8
-9
```

All of the first value lie outside the range 0..10 that the user requested the Range class to generate. However, not the least based on the word *Range* -- defined by Merriam Webster as ".. 7a: a sequence, series, or scale between limits" -- the user can expect this to produce an iterator that generates all values along the *trajectory* from `min` to `max`, interspaced by `step`. Therefore, no sequence value should lie *outside* `min .. max`.
The reason that Pony currently behaves counter to this in the cases described abover as *infinite*, is that it gives precedence to the combination of `min` and `step` and the iterative relationship `idx = idx + step` to produce the sequence values, regardless of the limits `min`, `max`. Algorithmically, it is currently designed as if saying: I know there are no elements (the implementation actually checks for this no-progress-possible within the given bounds situation), but I will walk indefinitely in the wrong direction because you told me so and hence I am infinite. Beside the creation of possibly unwanted infinite loops, the current behavior also precludes the use of `Range` like in cases where the programmer *knows* and *makes use of* the fact that if the bounds (and the step) are not compatible sign-wise, the range will have zero iterations.
As an example of what would be `expressive` use of the Range bounds, consider the following code fragment:

```pony
  ...
  let f: Array[Array[String]] = csv.read("data.csv", ",") // reads whatever conforms to csv and returns a (possibly empty) array
  for idx in Range(1, f.size()) do // start at 1 to skip header line
    ... // perform only if f is not empty and has at least 1 data line
  end
```

This currently leads to a hanging actor/memory crash because the Range(1, f.size()) instead of being empty iterates infinitely in cases when the file "data.csv" exists but is empty, leading to an empty array in f. This code isn't particularly elegant or safe (a guard regarding f.size() should be put here), but it can still serve an example for how a programmer who would expect this Range to be empty in case of an empty f Array could utilize the Range parameters directly to ensure that the for loop is not executed by writing `Range(1, f.size())`.

Another problematic example of the current implementation is the response to any of the parameters being `Nan`.

```pony
  let nan = F64 = F64(0) / F64(0)
  let r =  Range[F64](0, 10, nan)
  for i in Range(0, 10) do
    try env.out.print(r.next()?.string()) end
  end
```

```
0
-nan(ind)
-nan(ind)
-nan(ind)
-nan(ind)
-nan(ind)
-nan(ind)
-nan(ind)
-nan(ind)
-nan(ind)
```

Under the same argument regarding the iterator needing to adhere to the stated bounds `min, max`, this and some Range constellations that indefinitely produce `+-Inf` should also instead return empty ranges. `NaN` is not a value and can therefore not possibly lie within any valid range. The same is true when one of the bound parameters is `NaN`. Under this RFC Range iterators that use `NaN` in any parameter are *empty*.
As stated above, Pony currently consideres those Ranges *infinite* including those were the `min, max` bounds are finite and identical but the `step` parameter is `+-Inf`. These cases too would be treated as empty since no iteration is necessary to advance from `min` to `max` regardless of the magnitude of `step`.

# Detailed design

## Implementation

Currently, a Range is considered infinite if either 1) the `step` is `0`, any of `min`, `max`, or `step` are `NaN`, `+Inf` or `-Inf`, or 2) if no progress can be made from `min` to `max` due to the sign of the `step`. Here is the corresponding relevant portion of the current range.pony implementation:

> ```pony
> class Range[A: (Real[A] val & Number) = USize] is Iterator[A]
>   ..
> let _min: A
>   let _max: A
>   let _inc: A
>   let _forward: Bool
>   let _infinite: Bool
>   var _idx: A
> 
>   new create(min: A, max: A, inc: A = 1) =>
>     _min = min
>     _max = max
>     _inc = inc
>     _idx = min
>     _forward = (_min < _max) and (_inc > 0)
>     let is_float_infinite =
>       iftype A <: FloatingPoint[A] then
>         _min.nan() or _min.infinite()
>           or _max.nan() or _max.infinite()
>           or _inc.nan() or _inc.infinite()
>       else
>         false
>       end
>     _infinite =
>       is_float_infinite
>         or ((_inc == 0) and (min != max))    // no progress
>         or ((_min < _max) and (_inc < 0)) // progress into other directions
>         or ((_min > _max) and (_inc > 0)) 
> ```

This RFC partitions the set of currently *infinite* `Range` cases into those now considered *empty*, and a very small set of those that remain *infinite*.

For this, two criteria are postulated that are required for a Range to not be empty. Numeric values including the floating point values `+Inf` and `-Inf` can be meaningfully compared in expressions like `min > max` or `max > min`. Based on this, an obvious absence of *progress* of the iteration from min towards max based on the sign of the Range parameters can be tested by `((min <= max) and (step <= 0)) or ((min >= _max) and (step >= 0))` ("no-progress" criterion) for finite and infinite bounds as well as finite and infinite values of step (note that if either of the `min` or `max` parameters is `NaN` such expressions are always `false` and this special case is discussed further below). Here, besides the obvious sign-incompatibility of the three Range parameters, the cases of equal bounds `min == max` and `step == 0` are included, since the former wouldn't satisfy `[min, min)` (and also doesn't require any progress) and the latter prevents any progress. In the current implementation of Range, a somewhat similar couple of expressions are used with the comment `// no progress` and `// progress into other directions`, but they are treated as a sufficient condition for *infinite*. Here, this criterion is used as part of a test for empty Ranges because it allows us to know in which cases the generation of values between min and max is impossible, irrespective of the magnitude of the bounds or steps, in other words, no valid *trajectory* from min to max does exists with the provided parameters. The second important criterion used here is that for a Range iterators to be not empty, it must only produce finite values even when infinite bounds are specified, and if that is not possible, the Range is again *empty*.

Combining these two criteria, for a `Range` to not be *empty*, progress from `min` to `max` must be possible (no-progess is `false`), and the iterator that realizes this progress must produce *finite* values that lie within `[min, max)`.

Using this test, `Range(0, 10, -1)` is *empty* and no longer *infinite*, but so is in fact `Range(0, inf, -1)` that is also considered *infinite* currently. While one can generally never produce a complete list of elements that would incrementally move from say 0 to +Inf, we can know in the case of `Range(0, inf, -1)` that the Range must be *empty* because of the incompatible sign of the step parameter relative to the signs of `min` and `max` (progress impossible).
Another case in which a Range is now *empty* is when the bound equality `min == max` can be evaluated meaningfully, independent of whether `step` equals e.g. `0` or `+-Inf` such as for example `Range(10, 10, 0)`. In the case of equal and finite bounds, no value can exist that satisfies `[min, min)`. In case of infinite bound values, the range is also empty because one `inf` cannot be meaningfully tested for equality to another `inf` and even if it could, the second criterion would be violated in that a sequence of values would contain non-finite values.

As already stated, the current `Range` implementation treats the occurrence of `+-Inf` or `NaN` parameters in *any* of the `min, max, step` parameters as sufficient condition for *infinite*. This RFC considers the opposite: the no-progress expression cannot be meaningfully evaluated if any one of the 3 tested parameters is not a number, and one can also not decide whether any iterations `idx + NaN` lie within the given numerical range, or, if `min` or `max` are `NaN`, what that range is in the first place. Any occurrence of `NaN` in the Range parameters therefore produces an *empty* Range. Similarly, while a `step` argument of `+-Inf` may "pass" the inspection by the *no-progress criterion*, no finite points within the mathematical range `[min, max)` can be computed, including when `min, max` themselves are `inf`. Therefore, such Ranges are *empty*, too. A `step` argument of `0` satisfies the *no-progress criterion* and produces an *empty* Range.

The cases that would remain *infinite* under this proposal are then only those which fullfill the following condition: they are *not empty* (as per the evaluation above) AND their upper bound is either of the type `+Inf` or `-Inf`. Typical examples would be `Range[F64](0, inf, 1)` or `Range[F64](0, -inf, -1)`. We can't allow a lower bound that is not finite, because then the elements returned on .next() calls again would not be finite.

Summarizing this, the proposed algorithm for the Range classification is outlined in a close-to-code form. The following expressions are useful:

```
no_progress = ((min <= max) and (step <= 0) or (min >= max) and (step >= 0))
progress = not no_progress = ((min > max) or (step > 0)) and ((min < max) or (step < 0))
                           = (((min > max ) or (step > 0)) and (min < max)) or (((min > max ) or (step > 0)) and (step < 0)) // (min > max) and (min < max) == false; (step > 0) and (step < 0) == false
                           = ((step > 0) and (min < max)) or ((min > max ) and (step < 0))
                           = ((min < max) and (step > 0)) or ((min > max ) and (step < 0))
```

The above discussed combined criterion for *empty* was: either the no_progress criterion is true, or the generated values would not be finite. Finite values require both `min` and `step` to be finite, since the values are generated by an iterative addition of `step` to `min`. Therefore, one can state:

```
not_empty = progress and min.finite() and step.finite() // .finite() => the value is not `+-Inf` or `NaN`
infinite = not_empty and max.infinite()
empty = not not_empty
```

This can be implemented, replacing the above original code portion, as follows:

```pony
class Range[A: (Real[A] val & Number) = USize] is Iterator[A]
  ..
  let _min: A
  let _max: A
  let _inc: A
  let _forward: Bool
  let _infinite: Bool
  let _empty: Bool
  var _idx: A

  new create(min: A, max: A, inc: A = 1) =>
    _min = min
    _max = max
    _inc = inc
    _forward = (_min < _max) and (_inc > 0)
    (let min_finite, let max_finite, let inc_finite) =
      iftype A <: FloatingPoint[A] then
        (_min.finite(), _max.finite(), _inc.finite())
      else
        (true, true, true)
      end
    let progress = ((_min < _max) and (_inc > 0))
                    or ((_min > _max) and (_inc < 0)) // false if any is NaN!
    if progress and min_finite and inc_finite then
      _empty = false
      _infinite = not max_finite // ok to use not max_finite for max_infinite
                                 // since can_progress excludes _max == nan
      _idx = _min
    else
      _empty = true
      _infinite = false
      _idx = _max // has_next() will return false without code modification
    end
```

Importantly, the original code for `.has_next()` and `.next()` does not require any changes! A modifcation that conserves the implementation "trick" to initialize `_idx = _max` for empty Ranges is required to `.rewind()`. Also, analogous to the existing `.is_infinite(): Bool` function, there is also a new `.is_empty()`.

```
  fun ref rewind() =>
    if _empty then _idx = _max else _idx = _min end // currently _idx = _min

  fun is_empty(): Bool =>
    _empty
```

## Examples of Affected Ranges

Here is a list of Range examples all of which were previously infinite, and their new classification:

```
// newly empty Ranges
```

## Performance Notes

The changes proposed here are performance-wise mostly related to the `Range` constructor. Due to the proposed design, no code changes in the performance critical `.has_next()` and `.next()` calls were necessary. Therefore only the performance impact of the modified constructor (`create`) was estimated with the following crude code (where RangeOld is the renamed original code and Range the new one):

```pony
// runtime new constructor
var t0 = Time.millis()
for i in RangeOld(0, 10_000_000) do // original implementation
  let r = Range[A].create(min, max, step) // new implementation
end
var t1 = Time.millis()
..
// runtime current constructor
t0 = Time.millis()
for i in RangeOld(0, 10_000_000) do // original implementation
  let r = RangeOld[A].create(min, max, step) // new implementation
end
t1 = Time.millis()
```
This was compiled with `--debug` so that the optimizer would not remove the not further used range instances.


# How We Teach This

## Proposed Docstring

The current docstring contains roughly two parts: the first part, which would remain unchanged, talks about the general use, and the second part addresses infinite Ranges and the use of floating point arguments (including those producing infinite Ranges). The docstring is proposed to be changed only in the second part which currently reads:

> If the `step` is not moving `min` towards `max` or if it is `0`,
> the Range is considered infinite and iterating over it
> will never terminate:
> 
> ```pony
> let infinite_range1 = Range(0, 1, 0)
> infinite_range1.is_infinite() == true
> 
> let infinite_range2 = Range[I8](0, 10, -1)
> for _ in infinite_range2 do
> env.out.print("will this ever end?")
> env.err.print("no, never!")
> end
> ```
> 
> When using `Range` with  floating point types (`F32` and `F64`)
> `inc` steps < 1.0 are possible. If any of the arguments contains
> `NaN`, `+Inf` or `-Inf` the range is considered infinite as operations on
> any of them won't move `min` towards `max`.
> The actual values produced by such a `Range` are determined by what IEEE 754
> defines as the result of `min` + `inc`:
> 
> ```pony
> for and_a_half in Range[F64](0.5, 100) do
> handle_half(and_a_half)
> end
> 
> // this Range will produce 0 at first, then infinitely NaN
> let nan: F64 = F64(0) / F64(0)
> for what_am_i in Range[F64](0, 1000, nan) do
> wild_guess(what_am_i)
> end
> ```
> 

which could, for example, be modified to:

> If `inc` is nonzero, but cannot produce progress towards max because of its sign, the `Range` is considered empty and will not be produce any iterations. The `Range` is also empty if either `min` equals `max`, independent of the value of the step parameter `inc`, or if `inc` is zero.
> 
>   ```pony
>   let empty_range1 = Range(0, 10, -1)
>   let empty_range2 = Range(0, 10, 0)
>   let empty_range3 = Range(10, 10)
>   empty_range1.is_empty() == true
>   empty_range2.is_empty() == true
>   empty_range3.is_empty() == true
>   ```
>   
>   When using `Range` with  floating point types (`F32` and `F64`)
>   `inc` steps < 1.0 are possible. If any arguments contains
>   `NaN`, the range is considered empty. It is also empty if the lower bound `min` or the step `inc` are `+Inf` or `-Inf`. However, if only the upper bound `max` is `+Inf` or `-Inf` and the step parameter `inc` has the same sign, then the range is considered infinite and will iterate indefinitely.
> 
> ```pony
>   let p_inf: F64 = F64.max_value() + F64.max_value()
>   let n_inf: F64 = -p_inf
>   let nan: F64 = F64(0) / F64(0)
>   
>   let infinite_range1 = Range[F64](0, p_inf, 1)
>   let infinite_range2 = Range[F64](0, n_inf, -1_000_000)
>   infinite_range1.is_infinite() == true
>   infinite_range2.is_infinite() == true
>   
>   for i in Range[F64](0.5, 100, nan) do
>     // will not be executed
>   end
>   for i in Range[F64](0.5, 100, p_inf) do
>     // will not be executed
>   end
> ``` 
> 

Tests for the correct behavior can be added to `packages/collections/_test.pony` by adding a `_assert_empty` function analogous to the existing `_assert_infinite` function while adjusting the latter by removing cases that are no longer infinite from the current `_assert_infinite` tests.

# Drawbacks

This is a breaking change. Any existing code that relies on currently infinite iterators that under this RFC are no longer infinite (which are most) would not function properly. Any code that for example, in place of a `while true do` loop, uses:

```Pony
for i in Range[F64](F64(0) / F64(0)) do
  // runs forever unless "broken" out of
```

would no longer work as intended.

The current implementation also provides an `.is_infinite()` function to test whether the iterator will indefinitely return values. This function could be used in user code to *avoid* iterating over Ranges that might currently be infinite or to produce appropriate errors. Reducing the number of cases in which Ranges are infinite as proposed here might therefore produce side effects in existing code even if that code does not purposely use infinite Ranges as control structures like the first example. This could for example render undisplayed error messages that were used in combination with such tests. It is fair to state that a search of public Pony code on Github did not yield any uses of `.is_infinite()` outside test code associated with tests for the Range implementation. This could be taken as a sign that infinite Ranges and guarding code against their effects are not widely used. It is also worth noting that `.is_infinite()` will still return true for all remaining infinite Range cases so that any use as a guard should likely remain intact.

# Alternatives

A fair alternative is to leave everythin as it is. Pony has been in fairly wide-spread use academically and to some degree even commercially, without anyone reporting the issues that for the author were the reason to start working on this RFC -- which was hanging (eventually running out of memory) Pony code. One could therefore speculate that the side effects and instances in which currently infinite Ranges are created are sufficiently documented and known by the users of Pony.
Nonetheless, as laid out in the summary and motivation sections, the use of the word Range suggests a behavior that is different from the current one. Therefore, if this RFC is not accepted, I'd suggest to better point out how Pony's use of `Range` is contrary to both the mathematical meaning and the use of iterator objects of that name in many other programming languages, and how this can lead to infinite loops over unintendedly infinite `Range` iterators. The current Range docstring does state this behavior and provides an example (infinite_range2), but this is possibly not prominent enough given the gravity of the discrepancy between reasonable expectation and behavior.

>  If the `step` is not moving `min` towards `max` or if it is `0`,
>  the Range is considered infinite and iterating over it
>  will never terminate:
> 
> ```pony
> let infinite_range1 = Range(0, 1, 0)
> infinite_range1.is_infinite() == true
> 
> let infinite_range2 = Range[I8](0, 10, -1)
> for _ in infinite_range2 do
>   env.out.print("will this ever end?")
>   env.err.print("no, never!")
> end 
> ```

# Unresolved questions

None

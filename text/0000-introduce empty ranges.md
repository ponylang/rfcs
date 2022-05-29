- Feature Name: Introduction of empty Ranges
- Start Date: 2022-05-29
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

The RFC carves out a subset of cases that are currently defined as *infinite* by proposing to instead produce an *empty* `Range` in these cases. This makes `Range` behave more similar to the way that Python's range() and Rust's Range() behave, allowing one to write more natural code. The proposal also addresses (fixes) a corner case that is currently unecessarily producing *infinite* Ranges.

Overall, while it is possible that there are uses cases in which Range(min, max) with min > max is infinite rather than empty, they are not obvious. More importantly, *unintended* infinite iterations can produce indefinitely-running actors which appears counter the design of Pony. The RFC proposes a delineation of the so-far infinite cases into those cases in which a programmer would naturally expect a Range to be empty rather than infinite and cases that would remain infinite. Under the proposed changes, enough ways remain to purposely create infinite iterations using the `Range` class should there be a use case.

# Motivation

Currently, a Range is considered infinite if either 1) the `step` is `0` or any of `min`, `max`, or `step` are `NaN`, `+Inf` or `-Inf`, or 2) if no progress can be made from `min` to `max` due to the sign of the `step`.

This RFC proposes to address two separate issues associated with 1) and 2):

- Most importantly, case 2) above significantly differs from the way Range iterators are implemented in other modern programming languages such as Rust or Python, and as a matter of fact--if looked at it in the context for `for` loops--from the overwhelming number of programming languages, no matter how old.  
  In Python, the following produces no iteration
  
  ```python
  >for i in range(1, 10, 1):
      print i
  >
  ```
  
  whereas in decades-old BBC Basic and similar BASIC dialects, a `1` is printed.
  
  ```basic
  FOR I=1 TO 10 STEP -1: PRINT I: NEXT
      1
  ```
  
  Most importantly, theses loops are not considered to iterate *indefinitely* (infinitely). Therefore, in many modern languages with Range iterators, the fact that there is nothing to iterate over is taken into account with appropriately chosen Range `min` and `max` parameters. Consider the following Pony code fragment:
  
  ```pony
  ...
  let f: Array[Array[String]] = csv.read("data.csv", ",")
  for idx in Range(1, f.size()) do // start at 1 to skip header line
    ... // perform only if f is not empty and has at least 1 data line
  end
  ```
  
  Currently and counter the natural expectation, this code hangs since the Range is *infinite* when the file f existed but was empty. The reason is that in this case the Range expands to `Range[USize](1, 0, 1)` which again in Python and Rust would be considered empty but is currently infinite in Pony. While there are legitimate cases in which the current `Range` implementation returns infinite iterators, this particular case seems illogical since the iterator should produce a number of elements of `step` spacing on the *trajectory from min to max*. In the example above, no such elements can exists due to the sign mismatch between min, max, and step, and the returned Range should be empty rather than infinite -- like it is in Rust, Python, and others. The only reason why Pony creates an *infinite* range in this situation is that it, algorithmically, seems to be saying: I know there are no elements (the implementation actually checks for this "no progress possible" situation), but I will walk indefinitely in the wrong direction because you told me so and hence I am infinite, even though the number of elements on the expected tranjectory is zero. The big issue with this is that it precludes or makes very cumbersome the expressive use of the bounds like in the csv file example above in which the programmer *knows* and *makes use of* the fact that if the bounds (and the step) are not compatible sign-wise, the range will have zero iterations, i.e. be *empty*.

  The more legitimate classification of Ranges as infinite, for example in cases when `min` and `max` are different, finite, and `step == 0`, are not changed in this RFC. For such cases, at least the argument could be made that the number of iterations should become "infinitely large. Pony currently treats the *infinite* case as important enough to provide a test with `is_infinite(): Bool`. Since currently no empty Ranges are recognized, there is also no test for the far more likely to occur empty cases. For example, Rust provides a `is_empty()` method for these cases and this RFC proposes to add `.is_empty(): Bool` to Pony that behaves like the following Rust example:
  
  ```rust
  assert!( (3..3).is_empty());
  assert!( (3..2).is_empty());
  ```
  
  While one could maybe argue that a `for` loop could be bracketed by a test for `is_infite()` in the above example,
  
  ```pony
  ...
  let f: Array[Array[String]] = csv.read("data.csv", ",")
  let lines = Range(1, f.size()) 
  if not lines.is_infinite() then
    for idx in lines do // start at 1 to skip header line
      ... // perform only if f is not empty and has at least 1 data line
    end
  end
  ```
  
  it is fair to mention that currently no `Pony`-labeled code on Github other than test code for Range exists that would make use of .is_infinite(). Also, the above is unnecessarily cumbersome, and again prevents the expressive use of the Range bounds with calculated values.

- Secondly, case 1) above indiscriminately makes a `Range` infinite when *any* of the arguments is a floating point NaN or +-Inf. It does so on the grounds that in all such case no quantifyable progress could be made from `min` to `max` (quote from range.pony):
  
  > If any of the arguments contains `NaN`, `+Inf` or `-Inf` the range is considered infinite as operations on any of them won't move `min` towards `max`.
  
  However, this unecessarliy makes ranges infinite in which `min == max`. This proposal argues that `Range[F64](5, 5, nan)` or `Range[F64](5, 5, inf)` should be empty rather than being infinite since no single iteration is necessary to advance from `min` to `max` regardless of the magnitude of `step`.

# Detailed design

Currently, a Range is considered infinite if either 1) the `step` is `0`, any of `min`, `max`, or `step` are `NaN`, `+Inf` or `-Inf`, or 2) if no progress can be made from `min` to `max` due to the sign of the `step`. Here is the corresponding relevant portion of range.pony

```pony
class Range[A: (Real[A] val & Number) = USize] is Iterator[A]
  ..
  let _min: A
  let _max: A
  let _inc: A
  let _forward: Bool
  let _infinite: Bool
  var _idx: A

  new create(min: A, max: A, inc: A = 1) =>
    _min = min
    _max = max
    _inc = inc
    _idx = min
    _forward = (_min < _max) and (_inc > 0)
    let is_float_infinite =
      iftype A <: FloatingPoint[A] then
        _min.nan() or _min.infinite()
          or _max.nan() or _max.infinite()
          or _inc.nan() or _inc.infinite()
      else
        false
      end
    _infinite =
      is_float_infinite
        or ((_inc == 0) and (min != max))    // no progress
        or ((_min < _max) and (_inc < 0)) // progress into other directions
        or ((_min > _max) and (_inc > 0))
```

This RFC partitions the set of currently *infinite* cases into a subset now considered *empty* and a subset that remains *infinite*.

Part of the algorithmic basis on which this distinction is made is the fact that while not quantifyable, the floating point values `+Inf` and `-Inf` do have a sign that allows expressions like `min > max` or `max > min` to be meaningfully defined. Note that if either of the `min` or `max` parameters is `NaN` such expressions are always `false`. Based on this, an obvious impossibility of *progress* of the iteration from min towards max based on the sign of the Range parameters can be tested by evaluating `((min < max) and (step < 0)) or ((min > _max) and (step > 0))` for finite and infinite bounds as well as finite and infinite values of step. In the current implementation, this expression is used and commented as `// progress into other directions` as part of the infinite condition. The sign criterion is useful insofar that it allows one to know such progress is impossible despite the magnitude of the bounds or steps, i.e, the list of points of the trajectory from min to max in the given steps empty!
In this RFC, this expression is used to define one portion of the now *empty* Ranges in accordance with the natural expectation and the implementation of Range in other languages. Using this test, `Range(0, 10, -1)` is *empty* and no longer *infinite*, but so is in fact `Range(0, inf, -1)`, even though any finite steps would mathematically never produce progress towards an infinite bound. While one can never produce a finite list of elements that would incrementally move from 0 to +Inf, we can know in the case of `Range(0, inf, -1)` that such a list of elements must be empty because of the sign of the step parameter. 

The other case in which a Range is now *empty* is when the bound identity `min == max` can be evaluated meaningfully even when `step == 0` or `step == nan`. In the case of identical bounds, no iteration is needed regardless of the step magnitude. For the test of equality of bounds, this proposal requires the bounds to be finite in order for the Range to be *empty*. That is, like the original implementation, the proposed one acknowledges that one `inf` cannot be meaningfully tested for equality to another `inf`.

The cases that would remain *infinite* under this proposal are therefore those which are: *not empty* AND which have either `+Inf`, `-Inf`, or `NaN` values in any parameter, or a zero `step` parameter.
Here is the corresponding portion of the modified range.pony, illustrating these definitions:

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

    (let is_bounds_finite, let is_step_finite) =
      iftype A <: FloatingPoint[A] then
        (_min.finite() and _max.finite(), _inc.finite())
      else
        (true, true)
      end
    let no_progress = ((_min < _max) and (_inc < 0))
                   or ((_min > _max) and (_inc > 0)) // false if any is NaN
    _empty = no_progress
          or ((_min == _max) and is_bounds_finite)
    _infinite = not _empty
            and ((_inc == 0)
                or not is_bounds_finite
                or not is_step_finite)
    if _empty then _idx = _max else _idx = _min end // has_next() will return false without additional code
```

With a so-modified Range class and a new .is_emtpy() function, here is a list of Range examples all of which were previously infinite, and their new classification:

```
//Empty Ranges

Range(0, 10, -1): .is_empty() = true, .is_infinite() = false
Range(10, 0, 1): .is_empty() = true, .is_infinite() = false
Range(10, 10, 1): .is_empty() = true, .is_infinite() = false
Range(10, 10, -1): .is_empty() = true, .is_infinite() = false
Range(10, 10, 0): .is_empty() = true, .is_infinite() = false
Range(-10, -10, 1): .is_empty() = true, .is_infinite() = false
Range(-10, -10, -1): .is_empty() = true, .is_infinite() = false
Range(-10, -10, 0): .is_empty() = true, .is_infinite() = false
Range(0, 10, -1): .is_empty() = true, .is_infinite() = false
Range(10, 0, 1): .is_empty() = true, .is_infinite() = false
Range(10, 10, 1): .is_empty() = true, .is_infinite() = false
Range(10, 10, -1): .is_empty() = true, .is_infinite() = false
Range(10, 10, 0): .is_empty() = true, .is_infinite() = false
Range(10, 10, nan): .is_empty() = true, .is_infinite() = false
Range(10, 10, inf): .is_empty() = true, .is_infinite() = false
Range(10, 10, -inf): .is_empty() = true, .is_infinite() = false
Range(-10, -10, 1): .is_empty() = true, .is_infinite() = false
Range(-10, -10, -1): .is_empty() = true, .is_infinite() = false
Range(-10, -10, 0): .is_empty() = true, .is_infinite() = false
Range(-10, -10, nan): .is_empty() = true, .is_infinite() = false
Range(-10, -10, inf): .is_empty() = true, .is_infinite() = false
Range(-10, -10, -inf): .is_empty() = true, .is_infinite() = false
Range(0, 10, -inf): .is_empty() = true, .is_infinite() = false
Range(10, 0, inf): .is_empty() = true, .is_infinite() = false
Range(0, inf, -10): .is_empty() = true, .is_infinite() = false
Range(0, inf, -inf): .is_empty() = true, .is_infinite() = false
Range(0, -inf, 10): .is_empty() = true, .is_infinite() = false
Range(0, -inf, inf): .is_empty() = true, .is_infinite() = false
Range(inf, 0, 10): .is_empty() = true, .is_infinite() = false
Range(inf, 0, inf): .is_empty() = true, .is_infinite() = false
Range(-inf, 0, -10): .is_empty() = true, .is_infinite() = false
Range(-inf, 0, -inf): .is_empty() = true, .is_infinite() = false
Range(-inf, inf, -10): .is_empty() = true, .is_infinite() = false
Range(-inf, inf, -inf): .is_empty() = true, .is_infinite() = false
Range(inf, -inf, 10): .is_empty() = true, .is_infinite() = false
Range(inf, -inf, inf): .is_empty() = true, .is_infinite() = false

//Infinite Ranges

Range(0, 10, inf): .is_empty() = false, .is_infinite() = true
Range(0, -10, -inf): .is_empty() = false, .is_infinite() = true
Range(0, 10, nan): .is_empty() = false, .is_infinite() = true
Range(0, inf, 10): .is_empty() = false, .is_infinite() = true
Range(0, inf, 0): .is_empty() = false, .is_infinite() = true
Range(0, inf, inf): .is_empty() = false, .is_infinite() = true
Range(0, -inf, 0): .is_empty() = false, .is_infinite() = true
Range(0, -inf, -10): .is_empty() = false, .is_infinite() = true
Range(0, -inf, -inf): .is_empty() = false, .is_infinite() = true
Range(inf, 0, 0): .is_empty() = false, .is_infinite() = true
Range(inf, 0, -10): .is_empty() = false, .is_infinite() = true
Range(inf, 0, -inf): .is_empty() = false, .is_infinite() = true
Range(-inf, 0, 0): .is_empty() = false, .is_infinite() = true
Range(-inf, 0, 10): .is_empty() = false, .is_infinite() = true
Range(-inf, 0, inf): .is_empty() = false, .is_infinite() = true
Range(inf, 0, nan): .is_empty() = false, .is_infinite() = true
Range(0, inf, nan): .is_empty() = false, .is_infinite() = true
Range(-inf, 0, nan): .is_empty() = false, .is_infinite() = true
Range(0, -inf, nan): .is_empty() = false, .is_infinite() = true
Range(nan, 0, inf): .is_empty() = false, .is_infinite() = true
Range(0, nan, inf): .is_empty() = false, .is_infinite() = true
Range(nan, 0, -inf): .is_empty() = false, .is_infinite() = true
Range(0, nan, -inf): .is_empty() = false, .is_infinite() = true
Range(inf, inf, 1): .is_empty() = false, .is_infinite() = true
Range(inf, inf, -1): .is_empty() = false, .is_infinite() = true
Range(inf, inf, 0): .is_empty() = false, .is_infinite() = true
Range(inf, inf, nan): .is_empty() = false, .is_infinite() = true
Range(inf, inf, inf): .is_empty() = false, .is_infinite() = true
Range(inf, inf, -inf): .is_empty() = false, .is_infinite() = true
Range(-inf, -inf, 1): .is_empty() = false, .is_infinite() = true
Range(-inf, -inf, -1): .is_empty() = false, .is_infinite() = true
Range(-inf, -inf, 0): .is_empty() = false, .is_infinite() = true
Range(-inf, -inf, nan): .is_empty() = false, .is_infinite() = true
Range(-inf, -inf, inf): .is_empty() = false, .is_infinite() = true
Range(-inf, -inf, -inf): .is_empty() = false, .is_infinite() = true
Range(nan, nan, 0): .is_empty() = false, .is_infinite() = true
Range(nan, nan, 1): .is_empty() = false, .is_infinite() = true
Range(nan, nan, inf): .is_empty() = false, .is_infinite() = true
Range(nan, nan, -inf): .is_empty() = false, .is_infinite() = true
```

# How We Teach This

This can be taught by improving the documentation of `Range` and by discussing a few examples in the tutorial section. Also, as stated above, `Range.is_infinite()` is hardly used on Github and the impact of this change should be considered mild.

Tests can easily be added to `packages/collections/_test.pony` that would add a `_assert_empty` method and test for relevant cases while removing thoses cases from the current `_assert_infinite` tests.

# Drawbacks

* As far as I can tell from public code, Range.is_infinite() is not used in any Pony code other than test code associated with tests for Range.
* This should not produce any bugs in the compiler since it is a small library change only
* Maintenance cost should be marginal.

# Alternatives

The impact of not doing this are user code bugs in attempted uses of `Range` as shown in the motivation. At the very least the impact of loops over unintendedly infinite `Range` iterators should be minimized by either encouraging more use of `Range.is_infinite()` or by improved tutorials.

# Unresolved questions

What parts of the design are still TBD?

- Feature Name: range_redesign
- Start Date: 31/03/2019
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

A Range reimplementation that includes the features from collections.Reverse together with a more comprehensive and coherent API. A reference implementation can be found here: https://github.com/chobeat/pony-range-proposal

# Motivation

The existence of Range and Reverse as separate classes, each one with their own limitations, to cover a use case that in most languages is addressed by a single API highlights the possibility for an improvement. Having a single, well-tested implementation to generate numeric ranges will improve the quality of life of new developers and possibly reduce unexpected behaviors for a core piece of the stdlib.
For example in the existing implementation it is possible to generate infinite ranges without any explicit control. To check that a range is infinite, the user has to call the dedicated function (`is_infinite`) to be sure that its range will terminate. This unloads onto the user a lot of unnecessary checks that could be incorporated into the Range class. In addition to that, the current implementation doesn't allow to express a range spanning over a whole data type since it makes assumptions on the exclusiveness of the right bound. This prevents the user from creating a range that includes the max element of a given data type. 

One major conceptual change is to make the direction of the Range more implicit in the API and determined by the runtime values of the Bounds. Before this was more explicit since there were two distinct classes to cover both use cases. The direction was unambigous but it was less intuitive for people coming from other languages where a split of the two concerns (increasing and decreasing ranges) is not so common. On top of this, in a scenario where both directions are valid, with the previous implementation it was required to involve two different classes and a check on the bounds to pass, while now this would be covered transparently.

# Detailed design

The new implementation should fullfil the following design principles: 

* be able to generate all the possible ranges, increasing and decreasing, for all the data types, without incurring in overflow errors.
* offer a unified, usable, coherent API with the possibility to specify inclusive or exclusive bounds. To achieve this, the definition of the bounds and the range should be independent. The Range class should offer helper methods to cover the most common cases without explicitely instancing the bounds.
* never raise errors but instead return an empty list. This decision arises from the assumption that a majority of ranges are defined with bounds known at compile time while declaring ranges using runtime values is less common. The error handling in that case has to be done by calling the `is_invalid()` method. A version of the class with explicit errors can be considered.

The reference implementation solves these problems in the following way:

* implements a trait `Bound[T]`, implemented by two classes: `Inclusive[T]` and `Exclusive[T]` to represent the bounds. Each one of them will be able to return the value to be used to define the range in the case that they are used as an upper or lower bound.
* implements a class `Range` with a default constructor that respects the existing API
* implements a more flexible constructor with the following signature: 
 `new define(b: Bound[T], e: Bound[T], step: T=1)`. 
* Defines Step so that it cannot be negative or zero. In that case the range is considered empty. 
* Supports the notion of range direction. If b<e the range is defined as forward, otherwise backward. If b==e the range is empty.
* implements the additional constructor `to`, to support the case where the range starts at 0. Additional constructors can be considered.

Building on this, we can lay out a prospective structure for the `Range` class API.

```
class Range[T: (Real[T] val & Number) = USize]

  new create(lower:T, upper:T,step:T=1)
  new define(b: Bound[T], e: Bound[T], step: T=1)
  new to(e:T, step:T=1)
  fun is_forward():Bool
  fun is_invalid():Bool
  fun has_next(): Bool
  fun ref next(): T
  fun get_increment_step():T
  fun get_end():Bound[T]
  fun get_begin():Bound[T]
    
```



# How We Teach This

The API of the `Range` class is rather similar to the API of the `Range` implementations in many other languages. This should be documented in the stdlib documentation, explaining the basic usage alongside the details of the `Bounds` classes. On top of this, a dedicated example file can be produced, containing the intended usage of the API in scenarios where, for example, an error or an invalid range is produced.

In many languages you would also find explanations on how to create a range in every tutorial. Pony's tutorial is currently lacking coverage of the `collections` package but if and when it will be added, it should also contain an introduction to the `Range` class.

# How We Test This

* Test that the constructors actually set the fields as expected
* Generate partial and full ranges, forward and backward, for a given data type and verify that the returned iterator contains the expected values
* Verify that passing a negative step returns an empty iterator
* Verify that passing bounds with the same value returns an empty iterator
* Explicitely test the behavior of bounds around the min and max values to avoid overflow errors. In particular, one must verify that using the max or min value of a given data type as a bound produces a range that actually starts or ends with the value specified as a bound. 


# Drawbacks

* Some behaviors might differ compared to the old Range implementation. In particular, the range definitions that before would have created an infinite range, will now produce an empty range.
* The "empty list error" logic instead of explicit errors might surprise a fraction of the users. Also it might break some existing code.
* If a range is increasing or decreasing will depend on the specific values of begin and end, making the "direction" of the range known only at runtime without explicit checks on these values. Nonetheless this behavior can be observed by the user using `is_forward`.

# Alternatives

Some design choices presented alternatives. Some that have been considered:

* to raise errors
* not to support inclusiveness/exclusiveness
* to support a different range definition logic, i.e. (begin, step, number of elements)

The main alternative to the redesign as a whole is to keep the existing implementation.

# Unresolved questions

In the reference implementation, the overflow check doesn't behave correctly for floating point numbers. It might very well be just an implementation mistake but given the trickyness of floating point arithmetics, it might hide some complexity that might reverberate in the specs too. 

- Feature Name: range_redesign
- Start Date: 31/03/2019
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

A Range reimplementation that includes the features from collections.Reverse together with a more comprehensive and coherent API. A reference implementation can be found here: https://github.com/chobeat/pony-range-proposal

# Motivation

The existence of Range and Reverse as separate classes, each one with their own limitations, to cover a use case that in most languages is addressed by a single API highlights the possibility for an improvement. Having a single, well-tested implementation to generate numeric ranges will improve the quality of life of new developers and possibly reduce unexpected behaviors for a core piece of the stdlib.
For example in the existing implementation it is possible to generate infinite ranges without any explicit control. 

In addition to that, the current implementation doesn't allow to express a range spanning over a whole data type since it makes assumptions on the exclusiveness of the right bound.

# Detailed design

The new implementation should fullfil the following design principles: 

* be able to generate all the possible ranges, increasing and decreasing, for all the data types, without incurring in overflow errors.
* offer a unified, usable, coherent API with the possibility to specify inclusive or exclusive bounds. To achieve this, the definition of the bounds and the range should be independent. The Range class should offer helper methods to cover the most common cases without explicitely instancing the bounds.
* never raise errors but instead return an empty list. This is done to make the class more usable in day to day usage. A version of the class with explicit errors can be considered.

The reference implementation solves these problems in the following way:

* implements a trait `Bound[T]`, implemented by two classes: `Inclusive[T]` and `Exclusive[T]` to represent the bounds. Each one of them will be able to return the value to be used to define the range in the case that they are used as an upper or lower bound.
* implements a class `Range` with a default constructor that respects the existing API
* implements a more flexible constructor with the following signature: `
  new define(b: Bound[T], e: Bound[T], step: T=1)`. 
* Defines Step so that it cannot be negative or zero. In that case the range is considered empty. 
**** Supports the notion of range direction. If b<e the range is defined as forward, otherwise backward. If b==e the range is empty.
* implements two additional constructors `incl` and `to`, to support the case where both bounds are inclusive and the case where the range starts at 0. Additional constructors can be considered.

# How We Teach This

The API of the `Range` class is rather similar to the API of the `Range` implementations in many other languages. Explaining the basic behavior should be straightforward. The Bounds logic might deserve a dedicated explanation since it's necessary to use the default constructor and might be unexpected. 

The error management and the logic of the parameter `step` also deserve a dedicated explanation: while being similar to the logic seen in many other languages, in a quick survey we understood that the design of these behaviors have a much bigger variance and diversity across different languages. 

# How We Test This

* Test that the constructors actually set the fields as expected
* Generate partial and full ranges, forward and backward, for a given data type and verify that the returned iterator contains the expected values
* Verify that all the error conditions actually return an empty iterator (negative step, invalid bounds)
* Explicitely test the behavior of bounds around the min and max values to avoid overflow errors


# Drawbacks

* Some behaviors might differ compared to the old Range implementation 
* The "empty list error" logic instead of explicit errors might surprise a fraction of the users


# Alternatives

Some design choices presented alternatives. Some that have been considered:

* to raise errors
* not to support inclusiveness/exclusiveness
* to support a different range definition logic, i.e. (begin, step, number of elements)

The main alternative to the redesign as a whole is to keep the existing implementation.

# Unresolved questions

Some behaviors with float arithmetic are not really covered by the reference implementation and should be discussed.

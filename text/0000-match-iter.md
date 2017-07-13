- Feature Name: match-iter
- Start Date: 2017-07-13
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Add the ability to continue a regular expression match throughout a subject string multiple times. This will allow developers to run through matching the same regex against the same target in a for loop, to collect results into an array, etc.

# Motivation

Not all regular expressions can know the full extent or the total number of groups they're planning on capturing. If you want to capture the same pattern multiple times within a single subject string, today developers have to write their own iterator or while loop. Languages like `Rust` have an iterator built into their regular expression functionality and we would like Pony to have parity in this area.

# Detailed design

The implementation of this would be an addition to the standard library. We want to be able to jump from a validated regular expresion (e.g. the result of an `apply` on a `Regex`) to an iterator. One way to to this would be to add a `values()` method to `Match` that returns `Iterator[Match]`. 

By implementing this iterator in the standard library, developers will have access to this functionality in a standardized, reliable fashion. Here is an example of how this might be used where a single (first) `Match` is converted into an iterator via the idiomatic `values()` method:

```pony
let r = Regex("([+-]?\\s*\\d+[dD]\\d+|[+-]?\\s*\\d+)")
for m in r("3d6+10+1d20").values() do
   // process each of the three matches
end
```

# How We Teach This

The standard library documentation should be updated to include this new functionality and this functionality should be included in tutorials or samples involving regular expressions.

# How We Test This

Unit testing should be fairly straightforward for this. Edge case regular expressions to produce 0 matches, only 1 match, large numbers of matches, etc. should all be used in order to ensure that we get the iterator we expect.

# Drawbacks

This will increase the maintenance cost of the standard library

# Alternatives

The alternative to this is asking each developer who wants this ability to create their own `MatchIterator` class or to simply brute force this with a `while` loop.

# Unresolved questions

Decide which of the two variants is a more idiomatic/appropriate solution to this problem.

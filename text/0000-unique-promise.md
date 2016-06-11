- Feature Name: unique-promise
- Start Date: 2016-06-09
- RFC PR:
- Pony Issue:

# Summary

Add a `UniquePromise` to the `promises` package mirroring the `Promise` API for sendable objects (`iso`, `val`, `tag`) instead of shareable ones (`val`, `tag`).

# Motivation

The `Promise` API is great but can only be used to produce immutable or opaque results. Having a way to produce mutable isolated results would be really useful.

# Detailed design

A `Promise` can be fulfilled and share its result with an arbitrary number of chained `Promise`s, or be rejected and reject every chained `Promise`. An `UniquePromise` can deal with isolated results so this is not applicable here. A given `UniquePromise` can accept a chained `UniquePromise` only once and further attempts will be rejected. Because that uniqueness is part of `UniquePromise` semantics, trying to chain multiple `UniquePromise`s to the same `UniquePromise` is a logical error from the programmer and we do not need an `already_chained` special case on the notifier.

## Pony interface

`UniquePromise` actor:

```pony
actor UniquePromise[A: Any #send]
  """
  A promise to eventually produce a result of type A. This promise can either
  be fulfilled or rejected.

  A unique promise can be chained after this one.
  """

  be apply(value: A)
    """
    Fulfill the promise.
    """

  be reject()
    """
    Reject the promise.
    """

  fun tag next[B: Any #send](fulfill: UniqueFulfill[A, B],
    rejected: UniqueReject[B] = UniqueRejectAlways[B]): UniquePromise[B]
    """
    Chain a promise after this one. If there is already a chained promise, the
    new promise is rejected.
    """
```

Fulfill and reject interfaces and convenience classes:

```pony
interface iso UniqueFulfill[A: Any #send, B: Any #send]
  fun ref apply(value: A): B^ ?

interface iso UniqueReject[A: Any #send]
  fun ref apply(): A^ ?

class iso UniqueFulfillIdentity[A: Any #send]
  fun ref apply(value: A): A^ =>
    consume value

class iso UniqueRejectAlways[A: Any #send]
  fun ref apply(): A^ ? =>
    error
```

An example implementation can be found [here](https://gist.github.com/Praetonus/3f203a5a200208738e4ac8e49437326c).

# How We Teach This

We'll add examples of `UniquePromise` to the promises documentation and examples. The API is almost identical to `Promise` so there is no new elements for users.

# Drawbacks

None.

# Alternatives

None.

# Unresolved questions

None.

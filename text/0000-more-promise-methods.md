- Feature Name: more-promise-methods
- Start Date: 2017-02-25
- RFC PR: 
- Pony Issue: 

# Summary

This RFC proposes adding additional methods to the Promise actor.

# Motivation

The Promise actor is a useful tool for representing a value before it is available, though the public API is a bit sparse. Only 3 basic behaviors and functions are currently available to the user (apply, reject, and next). The following additional methods will improve composability and reflect common operations found in other promises/futures libraries.

# Detailed design

```pony

fun tag add[B: Any #share = A](p: Promise[B]): Promise[(A, B)]
	"""
	Add two promises into one promise that returns the result of both when they
	are fulfilled. If either of the promises is rejected then the new promise is
	also rejected.
	"""

fun tag join(ps: Iterator[Promise[A]]): Promise[Array[A] val]
	"""
	Create a promise that is fulfilled when the receiver and all promises in
	the given iterator are fulfilled. If the receiver or any promise in the
	sequence is rejected then the new promise is also rejected.
	"""

fun tag select(p: Promise[A]): Promise[(A, Promise[A])]
	"""
	Return a promise that is fulfilled when either promise is fulfilled,
	resulting in a tuple of its value and the other promise.
	"""

fun tag timeout(expiration: U64)
	"""
	Reject the promise after the given expiration in nanoseconds.
	"""
```
There will also be a `Promises[A]` primitive containing the following methods:
```pony
fun join(ps: ReadSeq[Promise[A]]): Promise[Array[A] val]
	"""
	Create a promise that is fulfilled when all promises in the given sequence
	are fulfilled. If any promise in the sequence is rejected then the new
	promise is also rejected.
	"""
```

# How We Teach This

Each method added will contain documentation as shown above and the package level documentation will be expanded to include examples for the new methods. The Pony Patterns book will also include examples for handling asynchronous events with promises.

# How We Test This

Each method will have a unit test in the promises package to ensure that the implementations work as intended.

# Drawbacks

These new methods will increase the maintenance cost of the promises package.

# Alternatives

Other methods may be added in addition or as replacements to the ones described above.

# Unresolved questions

None.

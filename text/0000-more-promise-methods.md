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

new many(ps: Array[Promise[A]] val): Promise[Array[A] val]
	"""
	Create a promise that is fulfilled when all promises in the given array are
	fulfilled. If any promise in the array is rejected then the new promise is
	also rejected.
	"""

fun tag join[B: Any #share = A](p: Promise[B]): Promise[(A, B)]
	"""
	Join two promises into one promise that returns the result of both when they
	are fulfilled. If either of the promises is rejected then the new promise is
	also rejected.
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

# How We Teach This

Each method added will contain documentation as shown above.

# How We Test This

Each method will have a unit test in the promises package to ensure that the implementations work as intended.

# Drawbacks

These new methods will increase the maintenance cost of the promises package.

# Alternatives

Other methods may be added in addition or as replacements to the ones described above.

# Unresolved questions

None.

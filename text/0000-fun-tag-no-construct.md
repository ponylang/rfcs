- Feature Name: fun-tag-no-construct
- Start Date: 2016-05-26
- RFC PR:
- Pony Issue:

# Summary

This change will allow for calling `tag` functions on a type expression, without needing to call the constructor for that type.

# Motivation

Currently, defining functions on `primitive`s is the most common way of simulating the concept of a function with no receiver (even though the `primitive` is the receiver, as a singleton of sorts).

The concept of a function with no receiver is closely related to the "static methods" found in some other object-oriented languages. These are commonly used for behaviour that is closely related to the instance methods, but that do not actually require being executed with a particular instance as the receiver.

This common idiom for classes in other object-oriented languages can only be simulated in Pony by introducing two types: a class to hold the "instance methods", and a primitive to hold the associated "static methods". This ends up being somewhat inconvenient and frustrating, because the two types need different names, and the type system doesn't really understand that you'd really like to treat them as a single type (for the purposes of being passed as type arguments, and so on).

# Detailed design

* The syntax `A.foo()` currently acts as syntax sugar for `A.create().foo()`, and only works if the `create` constructor for `A` has no required parameters.
    * Notably, the created instance is passed only to `foo`, and will be "dropped" if `foo` does not do something to cause it to be retained.
    * Since `foo` receives the only reference to the created `A` instance, the receiver capability of `foo` sets the upper bounds for the ref cap of the instance, if it is passed anywhere else in the program.
    * Therefore, if the receiver capability of `foo` is `tag`, the instance created in the expression `A.foo()` will always be opaque, and any fields it may have will never be read by `foo` or any subsequent function.
* If the `create` cosntructor for `A` has required parameters, the syntax `A.foo()` would currently cause a compiler error, since the constructor cannot be called without passing the required arguments.
* After this change, the above invalid code would be allowed if and only if the created instance was used as the receiver for a `tag` function.
    * In this case, the code would translate semantically to calling an implicit `new tag` constructor (that did nothing) instead of calling the `create` constructor.
    * In the implementation, we may not need to call any such constructor - it may be enough to simply return an opaque pointer to undefined memory.
* For backwards compatibility, `A.foo()` could still translate to `A.create().foo()` in cases where `create` has no required parameters - this would keep compatibility with existing code where the `create` may have side effects (through FFI).
* This enhancement would not be available for `actor`s, because messages can be sent to their opaque `tag` references. Those references are important, and not easily interchangable with pointers to arbitrary undefined memory.

# How We Teach This

* We should add a Pony pattern about simulating "static methods" from other object-oriented languages (using this approach).

# Drawbacks

* Admittedly, the behaviour here is a little less consistent than it was before. Still, we're only adding a working behaviour to code the previously wouldn't compile, and all code that previously compiled would still act the same.
* For `String`, this introduces the possibility that the resulting `String` may not be null-terminated. As explained in the design section, this is only of interest to programs and packages that use FFI calls which do not allow a length to be specified, and this problem can be mitigated by checking `is_null_terminated` and using `clone` if necessary.

# Alternatives

Other designs considered:

* Consider breaking backwards compatibility in favor of better consistency - apply the don't-call-`create` rule even in cases where `create` has no required parameters (and thus could easily be called). In short, this would break cases where the `create` method had side effects through FFI (or a library that uses FFI).

# Unresolved questions

None.

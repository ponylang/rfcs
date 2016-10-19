- Feature Name: stateful-primitives
- Start Date: 2016-10-19
- RFC PR:
- Pony Issue:

# Summary

Permit immutable fields on primitives.

# Motivation

The main motivation behind this RFC is performance.

We can currently simulate state in primitives by using pure functions with no parameters, like this:

```pony
primitive Data
  fun data1(): D1 val => recover D1(42) end
  fun data2(): D2 val => recover D2("foo") end
```

This kind of construct is useful to centralise constant and predetermined data for an algorithm, where that data is intrinsic to the algorithm and shouldn't be supplied by the user. For example, the use case that motivated the RFC is an implementation of the Secure Remote Password protocol, which uses predetermined huge numbers not fitting in builtin numeric primitives.

This pattern is far from optimal since a new object is created each time one of the functions is called. The objects being globally immutable and constructed in the same way, they effectively are equivalent from the user's standpoint. Therefore, being able to use a single object in every instance of the algorithm's state can be a huge performance win.

# Detailed design

The core idea is really simple, it boils down to allowing fields on primitives. Since a primitive is always `val`, viewpoint adaptation will ensure that fields can never be mutable and that they can be used without concern in multiple actors. The only difference with class fields is that primitive fields will have to be initialised in the `_init` function rather than in the constructor.

We don't want to allow actors in primitive fields because it would create patterns with globally accessible actors not created by the main actor. Since a primitive `_init` can't send messages, that restriction is already ensured.

## Isn't this ambient authority?

No, for two reasons.

First, the function and the field in the following primitive are semantically equivalent (with the exception of object identity but it is irrelevant here)

```pony
primitive Data
  let data_field: D val = recover D(42) end

  fun data_func(): D val => recover D(42) end
```

Second, access to the field can be controlled with public/private visibility and capability-like constructor parameters, like in the following example

```pony
primitive Data
  let data: D val = ...

  new create(cap: DataAuth) => None
```

Here, a `DataAuth` is required to get the instance of `Data` and thus to access the `data` field.

## Implementation concerns

- Field references (or field data in the case of `embed` fields) can be stored in the primitive instance. That means primitives wouldn't be constants in LLVM anymore but that's not really a concern since we can use type-based alias analysis to get that constness back.
- Primitive fields must stay alive until the end of the program, even if nothing references them. `pony_gc_acquire` and `pony_gc_release` can be used for this. Since fields are globally immutable, they wouldn't be traced when sending them in messages, which is nice.
- The associated memory would be owned by a new system actor. Currently memory in a primitive's `_init` is allocated in the context of the `Main` actor. That wouldn't be good with fields since it would mix user logic and system logic in the same actor.

# How We Teach This

This doesn't add any new concept so a simple mention in the tutorial would be a good start. A Pony pattern explaining the advantages and use cases would also be useful.

# How We Test This

The only real things that can potentially go wrong are bad reference counting and premature GC of fields. Extensive manual testing should ensure this isn't happening.

# Drawbacks

This will add a certain amount of code in the compiler, which will have to be maintained.

# Alternatives

- Use separate objects from primitive functions as described in Motivation. This can be really bad for performance.
- Pass data in a class. This can break encapsulation if the data is supposed to be intrinsic to the algorithm.
- Use the upcoming compile-time values. This can't work with FFI objects.

# Unresolved questions

None.

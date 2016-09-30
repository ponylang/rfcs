- Feature Name: embed-actor
- Start Date: 2016-09-29
- RFC PR:
- Pony Issue:

# Summary

This change will allow for embedding actors within other actors, as a method of extending, augmenting, or otherwise wrapping the API of another actor through composition.

# Motivation

To quote from the tutorial, Pony does not support inheritance, and promotes composition as an alternative paradigm:

> In some object-oriented languages, a type can inherit from another type, like how in Java something can extend something else. Pony doesn't do that. Instead, Pony prefers composition to inheritance. In other words, instead of getting code reuse by saying something is something else, you get it by saying something has something else.

For classes where we truly want to wrap another class, we can even use the `embed` keyword to remove extra overhead associated with dereferencing an internal object - the embedded object is laid out in the same memory space as the outer object, as if it were "part of" the object. The intuitive caveat is that the inner object must be constructed inside the constructor of the outer object.

For actors, composition is desirable but it comes with even more overhead than for classes. That is, the outer actor can only communicate with the inner actor by sending asynchronous messages. This leads to several classes of problems and pain points:

* Additional message passing overhead, including garbage collector tracing.
* The outer actor cannot call synchronous methods of the inner actor, the behaviours will not be executed immediately, and any results must be communicated indirectly as messages instead of as return values.
* Issues maintaining a correct chain of causality to determine the intended message order - when an extra layer of causal indirection is added, it can be difficult to enforce the correct "happens-before" relationships when some messages originating from outside both actors are sent to the outer actor, and some are sent to the inner actor.

In practice, I've found while writing the `pony-zmq` library that trying to optimize these boundaries for performance often involves having the intermediately composed actors acting as "matchmakers" for the outermost to connect to the innermost actors directly, instead of passing "hot path" messages through all of the intermediate actors. However, this usually results in muddying the "separation of concerns", and the actors end up having to know a lot about the implementations of eachother. This in turn breaks down a lot of the important benefits of composition. Furthermore, such patterns are generally not possible unless you control the source code of all the actors involved, making it difficult to create truly extensible libraries.

I argue that we need a mechanism for low-overhead actor composition, similar to how `embed` is used to for low-overhead class composition. In fact, I argue that the semantics and constraints of low-overhead actor composition are in concept quite similar to those of low-overhead class composition, such that they could share the same keyword (and much of the same implementation) without causing confusion or cognitive dissonance for the user.

That is to say, I propose we allow embedding actors in the same memory space as the outer actor, requiring that they be constructed in the outer actor's constructor (the same semantics as `embed` for a class). Additionally, the inner actor would share the "mailbox" and scheduling context of the outer actor, such that a behaviour of the inner actor could not execute in parallel with a behaviour of the outer actor.

# Detailed design

* The `embed` keyword would have different compiler constraints.
    * When the inner type is a `class`, the construct would be allowed, as it currently is.
    * When the inner type is an `actor`, instead of raising a compiler error, the construct would be allowed provided that the outer type is also an `actor`.
    * When the inner type is an `actor`, and the outer type is not an `actor`, a compiler error would be raised that explains the requirement.
* Just like an embedded `class`, and embedded `actor` must be constructed inside the constructor of the outer type.
* Just like an embedded `class`, and embedded `actor` is laid out in the same memory space as the outer type.
* An `actor` can only be embedded within another `actor` because they need to share the same "mailbox" and scheduling context.
    * It must be guaranteed that a behaviour of the inner actor must never be in parallel with a behaviour of the outer actor, or vice versa.
    * Therefore, the scheduler must treat the two (or more) as a single actor, for the purpose of scheduling work.
    * Additionally, the garbage collection protocol must treat the two (or more) as a single actor, for the purpose of garbage collection, ownership, and tracing.
* The outer actor may construct and hold the reference to the inner actor with a `ref`, `box`, or `tag` reference capability
    * However, `ref` and `box` will be the most useful, because holding a `tag` reference would eliminate the advantage of being able to call synchronous methods that had access to actor state.

# How We Teach This

* We should add a section to the tutorial about using `embed` to compose actors.

# Drawbacks

None.

# Alternatives

Other designs considered:

* Consider breaking backwards compatibility in favor of better consistency - apply the don't-call-`create` rule even in cases where `create` has no required parameters (and thus could easily be called). In short, this would break cases where the `create` method had side effects through FFI (or a library that uses FFI).

# Unresolved questions

* Is this technically feasible, in terms of how actor queues are stored?
* Would the compiler need to create a reified composite type for the total actor in order for the actor queues to be unified?
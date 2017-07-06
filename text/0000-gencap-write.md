- Feature Name: gencap-write
- Start Date: 2017-07-05
- RFC PR:
- Pony Issue:

# Summary

Add `#write`, a new gencap for use in type parameter constraints, implying the capability set: `{iso, trn, ref}`.

# Motivation

We have gencaps to act as capability sets in type parameter constraints, grouped by the situation in which you might want to use them:

| gencap   | `iso` | `trn` | `ref` | `val` | `box` | `tag` | summary                       |
|----------|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|-------------------------------|
| `#any`   |   X   |   X   |   X   |   X   |   X   |   X   | any possible cap              |
| `#send`  |   X   |       |       |   X   |       |   X   | sendable                      |
| `#alias` |       |       |   X   |   X   |   X   |   X   | alias as themselves           |
| `#share` |       |       |       |   X   |       |   X   | alias as themselves, sendable |
| `#read`  |       |       |   X   |   X   |   X   |       | alias as themselves, readable |

This proposal adds the following new gencap to the table:

| gencap   | `iso` | `trn` | `ref` | `val` | `box` | `tag` | summary                      |
|----------|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|------------------------------|
| `#write` |   X   |   X   |   X   |       |       |       | writable (can be written to) |

That is, the `#write` set could be used to write code that assumes an `iso`, `trn`, or `ref` would be reified there, and would allow mutation of the referenced object, provided that the strict read-and-write-uniqueness constraints of `iso` were followed.

Specifically, an object with a type constrained by `#write` could have `fun ref` methods called on it, provided that it met the conditions of receiver auto-recovery (all arguments are sendable and the return value is sendable or ignored).

### Motivating example:

The need for this gencap came up when writing mutator functions for mutable data structures, where the mutator function cannot be defined as a method on the receiver, and the mutator function needs to be able to mutate any mutable reference (`iso`, `trn`, or `ref`).

Because the mutator function needs to be able to mutate references with uniqueness guarantees (`iso` or `trn`), it must use the "borrowing" pattern of receiving the ephemeral reference as an argument, and consuming it in the return value so it retains ephemerality and may be "named" again by the caller.

There's no way to implement the "borrowing" pattern described above in a way that supports `iso`, `trn`, and `ref` without using a type parameter to specify which one you are accepting as an argument and returning as the return value. You could accept any of the three as an argument with `ref`, and you could return any of the three to the caller with `iso`, but you can't implement a method that receives a `ref` and returns it as an `iso`. Thus, you must require a type argument to say "I'm passing in a `trn`, and expect to get it returned to me as a `trn` - nothing more, nothing less".

To acheive this behaviour, the type parameter must be constrained to the set of capabilities between the two bounds of `iso` and `ref`. The `#write` capability as described above would represent the range between that upper and lower bound.

# Detailed design

The `#write` gencap would be added, implying the capability set: `{iso, trn, ref}`.

An implementation for review is available in the [feature/gencap-write](https://github.com/ponylang/ponyc/tree/feature/gencap-write] branch.

# How We Teach This

The `#write` gencap would be added to the "Capability Constraints" table of gencaps in the tutorial.

# How We Test This

Add test cases to the compiler to demonstrate correct operation.

# Drawbacks

* Another gencap to maintain correct compiler logic for.

# Alternatives

Leave it out, and have no gencap for this capability set.

# Unresolved questions

None.

- Feature Name: recover-with-receiver
- Start Date: 2020-08-26
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

This feature will expand recover syntax to allow general usage of
recovery as appears in automatic receiver recovery. The change
will make some use cases possible, while improving the performance
or ergonomics of some other use cases.

# Motivation

Currently, Pony supports two forms of recovery, `recover` blocks,
as well as automatic receiver recovery. In some cases, these are
equivalent. If we have a single variable `x: T iso`, then we can
temporarily use it as another capability inside a recover block,
with something like:
```
x = recover
   let x_ref = consume ref x
   // do something with x ...
   x_ref
end
```
Alternatively, if the action being taken is precisely a ref method call,
then automatic receiver recovery can be used if the
arguments and return types meet the isolation guarantees for `x`.
```
x.foo(y, z)
```
But this can't be used for every type of action, it needs to be those
actions thought of by the original class developer. We can add these methods,
but this is anti-modular.

This automatic receiver recovery syntax also works for expressions more complicated than a single variable of course.
The recover block is less flexible. The recover block method can be used only when the thing being modified is a mutable location.
It can be used with var fields, but not with let or embed. It can be used when we have update methods, but not with getters alone.
```
// defined elsehwere
class Foo
   fun box getSomething(): this->Bar ref
   ...
   fun box values(): this->FooIterator ref

class FooHolder
   embed foo: Foo iso = Foo
   // or let

   fun ref doSomethingWithFoo() =>
      // error, iso->ref = tag
      foo.getSomething().somethingElse()

      // try to recover to use foo as ref: error, can't assign
      foo = recover
         ... consume foo
      end
   end
```
We might also have read-only methods. Imagine we take in an Iter over iso objects. We don't want to be coupled to
the class used, such as Array, and allow a generic, potentially chained iterator.
```
class UsesIter[T: SomeInterface]
   fun process(iter: Iterator[T]) =>
      // want to call a few complicated methods on T
      // if T might be unique, we can't store in a variable,
      // so we want to recover, but we can't!

      // error, not a subtype
      let next: T = iter.next()?

      // ????
      iter.next() = recover
         ...
      end

      // works... but only if we can
      // express *all* of the things we want
      // to do as multiple methods
      // still anti-modular!
      iter.next()?.foo().>bar()
   end
```

This RFC will add a syntax to expand the design of recover blocks to allow a receiver, subsuming automatic receiver recovery.
In both cases above, the recover with receiver may be used in order to temporarily use these values as ref, allowing free
usage of methods, without requiring that the methods were defined ahead of time in the interface or class, and without
requiring extra potentially erroring accesses or allocating and swapping new values via update methods.

# Detailed design

We will add new syntactic forms to allow recover blocks based around an existing receiver expression.

```
e1.recover | x =>
   e2[x]
end
```
and shorthands
```
x.recover
   e[x]
end
```
and shorthands
```
x.f.recover
   e[f]
end
```

Where in both cases, `e` is an expression, and `x` is a variable binding. In the second case, the first `e` should be either a variable or a field access.
Inside the body of the recover block, the variable `x` will be bound as a `let` binding. For the shorthand, the name of this variable will be the name
of the variable that the expression is, or the rightmost field name.

The capability of the new binding will depend on the capability of the expression. If it is a unique capability, `iso` or `trn`, then the resulting capability
will be the strongest aliasable type: `ref`. If it is any self-aliasing capability `k`, then the resulting capability will be `k`.
Acknowledging that there might be better choices available, at this time `iso^` or `trn^` will take the capability `ref` and act identically to their
non-ephemeral counterparts.

To soundly access the outside environment, we must use a few provisions:
* As in any recover block, the outside environment can be accessed only via sendables
* All variables which were used in the receiver of the block are considered in-use (and cannot be consumed)
* To prevent invalidation, the outside environment should be accessed only immutably (though this condition can be loosened for provably disjoint references).
  This does not prevent consuming `iso` variables to move into the recover block, as they are always disjoint from the receiver.

The value which is returned will be viewpoint-adapted according to the capability of the receiver. This subsumes the existing conditions for the returns of automatic receiver recovery.

For a method call to a `ref` method, it can be treated as being wrapped in an implicit receiver recovery block. That is,
`x.f(y, z)` can be de-sugared to:
```
let a1 = y
let a2 = z
x.recover
   x.f(consume a1, consume a2)
end
```
Note that the arguments are evaluated ahead of time, and then consumed. This is how automatic receiver recovery prevents invalidation today, by allowing
no execution to take place after the receiver has been determined.


# How We Teach This

We can refer to this feature as either reciever recovery or recovery with receiver. The section on recover blocks will be modified with an additional section to
reflect the new type of recover blocks. Examples should reflect some of the previously impossible use cases above, as this helps in explaining usage of isolated capabilities in data structures.

The existing cases of automatic recovery, when calling ref methods, and constructors, will be presented together as conveniences, as it is now a truly representable
form of recovery.

# How We Test This

This will require additional tests for different receivers and both of the unique capabilities. Existing tests around automatic receiver recovery should be maintained and should continue to pass.

# Drawbacks

Why should we *not* do this? Things you might want to note:

* This may frontload recovery concepts slightly sooner for learners, rather than just presenting receiver recovery for functions
* Generic technical costs of new features

# Alternatives

We may try to expand automated recovery to handle more cases like the above, at the cost of a lack of simplicity.

# Unresolved questions

* The syntax may still need work.
* Research has not fully caught up to more powerful recovery mechanisms as a general detail.
* Some methods may be given more flexible types, but these can't be easily expressed generically. Should we add new connectives?

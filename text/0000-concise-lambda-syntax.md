- Feature Name: concise-lambda-syntax
- Start Date: 2016-10-20
- RFC PR:
- Pony Issue:

# Summary

This proposal shortens the lambda literal syntax to match the concise lambda type syntax.

# Motivation

In an actor language like Pony where all work crossing an actor boundary must take place asychronously, lambdas are a critical feature, whether chained to promises or as direct callbacks to asynchronous operations.

However, in my experience with Pony codebases lambdas aren't as widely used as you might otherwise think, and I believe this is due to a set of usability issues that make dealing with lambdas more painful than it should be. One of these issues is that they are not very concise in syntax.

The syntax becomes especially jarring when passed as an argument to a method (arguably one of the most common things to do with a lambda). Any attempt to pass the lambda inline gives you a block with `end` inside of your function parentheses, which ends up as a bit of an eyesore:

```pony
let c = a.map[U32](lambda(a: U32): U32 => a * 2 end)
```

To compensate, we often define the lambda ahead of time to keep it outside the parentheses (in fact, this example is taken directly from the standard library tests):

```pony
let f = lambda(a: U32): U32 => a * 2 end
let c = a.map[U32](f)
```

However, this undermines expressiveness - we've essentially created a path of least ugliness that favors creating the lambda first and assigning it a "throwaway" identifier instead of putting it directly inline. This becomes a bigger problem for the case of APIs that use promises, where you really want to convey a notion of "do this, then do this with the result", but defining the lambda first creates a disjunction between the code order and the order of execution:

```pony
let update_foo_fn = lambda(db: Database, doc: Document) =>
  doc.foo = "foo2"
  doc.bar = "bar2"
  db.update(doc)
end

db.get(doc_id).next[None](update_foo_fn)
```

# Detailed design

This proposal updates the syntax for lambda literals to match the syntax for lambda types. Here is the syntax (as it already exists in Pony) for a basic lambda type used as the parameter for a `map` method:

```pony
class MyU32Collection
  fun map(fn: {(U32): U32} box): MyU32Collection =>
    // ...
```

And here is a example for passing a simple lambda literal to that map method:

```pony
let c = a.map[U32]({(a: U32): U32 => a * 2})
```

Note that the `lambda` has been replaced with `{` and the `end` has been replaced with `}`.

Here's our promise API example from before, with the new syntax and the lambda inlined into the `next` method call:

```pony
db.get(doc_id).next[None]({(db: Database, doc: Document) =>
  doc.foo = "foo2"
  doc.bar = "bar2"
  db.update(doc)
})
```

The curly braces provide clear separation of context, but also inline elegantly into the parentheses. The consistency with the lambda type syntax is a huge bonus, and should make it easier to teach both.

Arguably, it could be said that it is less obvious to a casual reader that this is a lambda (since the word `lambda` is no longer used verbatim in the syntax), but generally, the parameter list followed by "fat arrow" `=>` should be a pretty good indicator for anyone who is even passingly familiar with Pony syntax that you're looking at some kind of anonymous function. I would argue that using this form for lambda literals also makes the existing syntax for lambda types much less cryptic by extension.

# How We Teach This

All documentation and examples should demonstrate the new format.

The tutorial appendix with the list of symbols should include curly braces as an indicator of both lambda types and lambda literals.

# How We Test This

Pony compiler and package tests using the old lambda syntax should be updated to use the new lambda syntax.

# Drawbacks

* Breaks existing code
* Curly braces don't fully match the general Pony style of `someword ... end`

# Alternatives

* Keep the existing lambda syntax unchanged.
* Allow users to continue using the old more verbose syntax if they choose (basically, allowing two different ways to write the same lambda literal)

# Unresolved questions

None.

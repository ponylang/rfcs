- Feature Name: lamdba-and-array-inference
- Start Date: 2017-07-16
- RFC PR: https://github.com/ponylang/rfcs/pull/95
- Pony Issue: https://github.com/ponylang/ponyc/issues/2094

# Summary

Improve inference for lambdas and array literals, allowing implied information to be omitted in cases where there is a definite type on the "left hand side" (which I'll refer to in this document as the "antecedent").

# Motivation

### Lambdas

Conceptually, lambdas have a very important role in the kinds of patterns we want to create for information flow in Pony, especially when you need some lightweight glue code for the asynchronous relationship between two otherwise decoupled types. For example, in such a situation you might use a `Promise` that is passed lambdas to execute on fulfillment, or you might use a lambda directly as a callback function instead of as part of a `Promise`. Lambdas can also be very important in synchronous patterns as well, particularly relating to functional programming operations on a data structure such as map, filter, and reduce (demonstrated in the `itertools` package).

In practice however, working with lambdas in Pony often ends up being more frustrating than we hoped. This is particularly true of lambda reference capabilities, which are not required to be explicit, but are currently inferred only from intrinsic properties of the written lambda, not from any extrinsic context. Often this means that a lambda that a user writes to use with a promise, or as a callback, or as a transformation gets rejected for not matching the required interface, even in cases where the explicit parts of the lambda that were written could conceivably match that interface if the implicit parts were inferred correctly. This ends up being a major pain point for most everyone that works with Pony lambdas.

Let's look at an example, adapted from [the "Access" pattern in the Pony Patterns cookbook](https://ponylang.gitbooks.io/pony-patterns/content/async/access.html).

Consider a `SharedRegisters` actor, which provides transactional access to some named numeric registers:

```pony
actor SharedRegisters
  let _data: collections.Map[String, I64] = _data.create()

  be access(fn: {(SharedRegisters ref)} val) =>
    fn(this)

  fun ref write(name: String, value: I64) =>
    _data(name) = value

  fun ref read(name: String): I64 =>
    try _data(name) else 0 end
```

If we wanted to increment a specific register named "apples", we could write a simple program like this, using a custom lambda that provides the increment logic for the access transaction:

```pony
actor Main
  let _reg: SharedRegisters

  new create(env: Env) =>
    _reg = SharedRegisters
    increment_apples()
    increment_apples()

  fun increment_apples() =>
    _reg.access({(reg: SharedRegisters ref) =>
      reg.write("apples", reg.read("apples") + 1)
    })
```

Now let's say we want to implement a more general increment operation, that can work on any given register rather than hard-coding the register name "apple". We could accept the name as a parameter to the function, then let the lambda close over it, like so:

```pony
actor Main
  let _reg: SharedRegisters

  new create(env: Env) =>
    _reg = SharedRegisters
    increment("apples")
    increment("apples")

  fun increment(name: String) =>
    _reg.access({(reg: SharedRegisters ref) =>
      reg.write(name, reg.read(name) + 1)
    })
```

However, this example won't compile - you'll see an error like:

```
/tmp/test.pony:24:17: argument not a subtype of parameter
    _reg.access({(reg: SharedRegisters ref) =>
                ^
    Info:
    /tmp/test.pony:24:17: {(SharedRegisters ref)} ref is not a subtype of {(SharedRegisters ref)} val: ref is not a subcap of val
        _reg.access({(reg: SharedRegisters ref) =>
                    ^
```

What's happened is that Pony is now sugaring the lambda to an anonymous `class` instead of an anonymous `primitive`, because it has state and must be instantiated every time to create a new instance of the lambda with that state. The issue is that a `class` uses `ref` as the default capability instead of `val`, so the lambda too will now be a `ref` instead of `val`, even though a `val` is what we needed, and a `val` is still possible here surrounding the lambda in a `recover` block, or by appending `val` after the closing `}` of the lambda.

Most of the useful cases for lambdas involve passing them as arguments to methods, whether as callbacks to asynchronous behaviours, or as synchronous transformations on a data structure. Even in cases that are not actually passed as arguments, you still typically have a definite type that is being assigned to.

As such, the author of this RFC believes that the most useful type of inference for lambdas is not right-to-left, but left-to-right. That is, in cases where the lambda has a definite type on the "left hand side" (an antecedent type), we should try to make anything that is indefinite or ambiguous about the lambda literal match that antecedent type, since it will have to match anyway in order to avoid compiler errors later.

However, we don't want to needlessly break existing code, so in the absence of an antecedent type, the existing intrinsic inference rules should remain.

### Array Literals

Array literals have a very similar problem with intrinsic inference, in that they can only infer the element type argument of the array by building and flattening the union type of all literal elements in the array. This has several frustrating consequences for the user.

One consequence is that in cases where the elements don't have the same "final type" (they have a `trait` or `interface` in common but are not of the same `class`, `actor` or `primitive`) the union of the types of the elements in the literal is not usually what you wanted for the element type arguemnt. If you wanted to use a element type argument of the `trait` or `interface` that they all have in common, then you have to specify that explicitly using the `as MyTrait:` syntax at the beginning of the array literal. Pony currently can't guess this for you, because there's no way to infer that intrinsically without the compiler making too many assumptions about *which* common interface you were intending to use.

However, it *can* be inferred from an antecedent if one is available, just like the implicit information in lambdas. If I'm assigning my array literal to a field or local variable that has an explicit type of `Array[MyTrait]`, there should be no reason to have to also specify the element type using the `as MyTrait:` syntax - the compiler should be able to infer it from the antecedent.

Apart from the element type problem, arrays also must be explicitly recovered if you want to "lift" them to a capability "higher than" `ref`, like `iso`, `trn`, or `val`. This is similar to the lambda capability problem, in that the compiler should be able to know from the antecedent that I was trying to create, for example, and immutable array literal (`val`). This is especially common in cases where I want to pass an array literal as an argument to a function that expects the array literal to be immutable so that it is sendable - the compiler knows a `val` is expected, so it should be able to implicitly recover it, which will work as it passes the normal rules of recovery.

Again, we don't want to break existing code, so the intrinsic inference rules and the `as` syntax should continue to work (and continue to be necessary if no antecedent type could be found).

# Detailed design

### Finding an Antecedent

For arrays and lambdas, the compiler will look for antecedent types. The compiler will work its way upward through branches and levels of expressions until it finds a place where an explicit type is given, such as an assignment, or a parameter signature of a method call.

If no antecedent type is found (for example, the assignment has no explicit type, and is inferring from right-to-left), the existing rules for intrinsic inference will be in effect.

If an antecedent type is found, the compiler will determine if it is a "plausible" antecedent type for the kind of expression we're dealing with. For lambdas, it will look for a type that is an interface with a single method. For arrays, it will look for an `Array` type with a specific element type argument, or for an interface that contains a `fun apply(i: USize): this->A` method (such as `ReadSeq[A]`).

The compiler will dig through complex types in the antecedent type (such as unions and intersections) to try to find a plausible one. The compiler may not handle every possible case, especially in the first iteration of the implementation, but limitations in the inference will be clearly documented in the tutorial.

### Applying the Antecedent

For arrays, the antecedent type will be applied to the expression by selecting the most specific element type argument that will make the expression match the antecedent type.

For lambdas, the antecedent type will be applied by filling in any missing details in the lambda with the corresponding details from the antecedent type's signature for that method, *including details that weren't allowed to be omitted before*. That is, if the object capability and/or the receiver capability are missing, we'll fill them in from the antecedent type. More interestingly, if any of the *parameter types* or *return type* is missing, we can fill those in as well.

### Implications

Note that for arrays, this means that arrays of literals no longer will require the `as I64:` syntax to be mandatory.

It also means that we can allow empty array literals, which aren't possible in Pony currently. The following example of today's syntax:

```pony
let array: Array[MyTrait] iso = recover Array[MyTrait] end
```

... could be cleaned up to look like:

```pony
let array: Array[MyTrait] iso = []
```

Note that for lambdas, this means we can now allow omitting the return type, parameter types, and even replacing unused parameters with the "don't care" symbol (`_`). For example, the lambdas in the following example would all be equivalent:

```pony

primitive X
primitive Y
primitive Z
type Fn is {iso(X, Y): Z} iso

primitive Test
  fun test(fn: Fn) => None
  fun apply() =>
    test({iso(x: X, y: Y): Z => Z } iso)
    test({iso(x: X, y: Y): Z => Z })
    test({(x: X, y: Y): Z => Z })
    test({(x: X, y: Y) => Z })
    test({(x: X, y) => Z })
    test({(x, y) => Z })
    test({(_, _) => Z })
```

This kind of concise syntax could be incredible convenient for use of things like the `itertools` package, where the verbosity and redundancy of lambdas can often be tiresome. Take this example from the docstring:

```pony
Iter[I64]([as I64: 1; 2; 3; 4; 5].values())
  .map[I64]({(x: I64): I64 => x + 1 })
  .filter({(x: I64): Bool => (x % 2) == 0 })
  .map[None]({(x: I64) => env.out.print(x.string()) })
  .run()
```

... which, with the improvements to both arrays and lambdas could be cleaned up to look like:

```pony
Iter[I64]([1; 2; 3; 4; 5].values())
  .map[I64]({(x) => x + 1 })
  .filter({(x) => (x % 2) == 0 })
  .map[None]({(x) => env.out.print(x.string()) })
  .run()
```

# How We Teach This

The tutorial section on lambdas would be expanded to include a summary of this information.

Existing code in the standard library and examples would be refactored to take advantage of these improvements where appropriate.

# How We Test This

Add test cases to the compiler to demonstrate correct operation.

# Drawbacks

* Expands the complexity of the expr pass in the compiler that we're responsible for maintaining.

# Alternatives

Leave it out, and don't provide left-to-right inference for anything but numeric literals.

# Unresolved questions

None.

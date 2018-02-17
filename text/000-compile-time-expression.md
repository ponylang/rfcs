- Feature Name: Compile-Time Expressions
- Start Date: 17/02/2018
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Adding compile-time expressions to pony, these are pony expressions which are evaluated by the compiler.

# Motivation

Compile-time expressions allow the developer to evaluate parts of their program at compile-time, this reduces some of what is to be evaluated at run-time. Consider an expression that always evaluates to the same result, using compile-time expressions allows the compiler to replace this expression with the result whilst retaining the original semantics of the expression in the source.

An example of an expression that we may want the compiler to evaluate follows:
```
  let myverrylongstring = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi rutrum sodales metus, quis elementum ex dignissim non. Maecenas non consectetur metus, sed accumsan orci. Nam vel orci at leo rhoncus blandit. Donec malesuada varius nisl."
```

The examples considers a very long string that nobody would really want to write on a single line. The alternative would be as follows:
```
  let myverrylongstring = "Lorem ipsum dolor sit amet, consectetur adipiscing elit." +
                          "Morbi rutrum sodales metus, quis elementum ex dignissim non." +
                          "Maecenas non consectetur metus, sed accumsan orci." +
                          "Nam vel orci at leo rhoncus blandit. Donec malesuada varius nisl."
```

Whilst more readable, the compiler will now generate 4 string literals when only 1 was desired. If we now use compile-time expressions:
```
  let myverrylongstring = #("Lorem ipsum dolor sit amet, consectetur adipiscing elit." +
                          "Morbi rutrum sodales metus, quis elementum ex dignissim non." +
                          "Maecenas non consectetur metus, sed accumsan orci." +
                          "Nam vel orci at leo rhoncus blandit. Donec malesuada varius nisl.")
```
We get the best of both, a string split over several lines but we only generate one string literal.

Compile-time expression also pave the way for future features such as value-dependent types, value-depedent types become much more powerful when one can evaluate simple or complex expressions and use them to instantiate types.

An interesting point is initialisation code. Sometimes one must write some code that is required to be run at startup time (for example generating some data-structure need by an actor), this introduces the overhead of ensuring that some actor is run to perform this initialisation. If the initialisation can be written as a compile-time expression then one can use compile-time expressions to ensure the compiler performs the initialisation and leaves the result in its place.

There are probably many more use cases that I have not considered and I would be interested to hear about them.

# Detailed design

A compile-time expression in pony is an opt-in feature, an expression that is to be evaluated at compile-time is denoted by a `#`. An example of this is:
```
actor Main
  new create(env: Env) =>
    let x: U32 = # (1 + 2)
```
Here `x` will be evaulated at compile-time. The compiler does not attempt to evaluate expressions that are not prefixed with the `#`. `#` will become part of the pony syntax (a keyword) and not an operator.

The `#` keyword has the strongest precedence, consider the following:
```
actor Main
  fun apply(): U32 => 2
  new create(env: Env) =>
    let x: U32 = # 1 + apply()
```
In this case only the `1` is evaluated at compile-time, the `+ apply()` will be evaluated at run-time.

There is no special subset of the language that will be created for compile-time expressions. This does not mean that all expressions will (or can) be permitted to be evaluated at compile-time. I think a large subset of the pony language should be permitted to be evaluated at compile-time; however this is a fairly large task so I think this will have to be an ongoing task, hopefully getting to the point were adding a new language feature involves adding support for runtime and compile-time. This means that most of this RFC will be covered by saying, compile-time expressions will behave as the runtime equivalent.

To this end, support for this feature will involve building a kind of interepreter for pony. There will notable restrictions to compile-time expressions, `actor`s and `behaviour`s can not be compile-time expressions. These restrictions are made as it does not make sense to have parallel execution of actors at compile-time.

Compile-time expressions are pure functional expressions, they cannot have side-effects. This is because these cannot be reflected in the runtime in the same way, consider printing to `env.out` at compile-time.

One effect of allowing most pony features is that this involves function calling a iteration, one must be careful to ensure that we do not cause infinite loops of execution in the compiler.

This is pony so we must make some consideration for reference capabilities. The result of all compile-time expressions will be `val`. Making compile-time expressions result in a `val` value means that the we can use the value later on in the program. Consider the following:

```
class Wombat
  var x: U32 = 2

  fun ref apply() => x = x + 1

actor Main
  new create(env: Env) =>
    let w: Wombat val = # Wombat
    let x: U32 = # (w.x)
```

In the above we can consider `w.x` to be a compile-time expression as `w` is compile-time constructed object and because it is `val` the value of `w.x` could not have changed since the object was constructed.

This means any expression to be evaluated at compile-time must be recoverable to `val`.

An aside; making the result `val` also allows the compiler to generate compile-time values as constant values, one could imagine this permits more optimisations to be performed on the value.

There is some discussion to be had about whether we can introduce new semantics to the language using compile-time expressions. An example of new semantics considers how a compiler handles the 'error' expression; take the following snippet:
```
actor Main
  fun check(x: U32): U32 ? => if x < 10 then error else x end

  new create(env: Env) =>
    # check(3)
```
Here, we have some method `check`

- Issues with target specfific things

If you are interested in exploring this feature please look at my current implementation of compile-time expressions [here|https://github.com/lukecheeseman/ponyc]

# How We Teach This

What names and terminology work best for these concepts and why? How is this idea best presented? As a continuation of existing Pony patterns, or as a wholly new one?

Would the acceptance of this proposal mean the Pony guides must be re-organized or altered? Does it change how Pony is taught to new users at any level?

How should this feature be introduced and taught to existing Pony users?

# Drawbacks

Why should we *not* do this?

# Alternatives

What other designs have been considered? What is the impact of not doing this?

# Unresolved questions

What parts of the design are still TBD?

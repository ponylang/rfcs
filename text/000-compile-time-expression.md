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

Compile-time expressions also pave the way for future features such as value-dependent types, value-dependent types become much more powerful when one can evaluate simple or complex expressions and use them to instantiate types.

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

## Capabilties

This is pony so we must make some consideration for reference capabilities. Here I describe two alternatives:
1. Compile-time expressions have the same capability as the expression.
2. Compile-time expressions are always val.

### 1. Compile-time expressions have the same capability as the expression

In this case, the compile-time expression has the same capability as the expression prefixed by `#`. Consider the following:

```
class C1
  var x: U32
  new create(x': U32) => x = x'

class C2
  var f: C1
  new create(x: U32) => f = C1(x * 2)

actor Main
  new create(env: Env) =>
    let c: C2 = # C2(6 + 4)
    c.f.x = 72
```

In this case `c` is of type `C1 ref`. Using this approach, objects are allocated (on the heap of the current actor) and then the fields are initialised with values computed at compile-time (with nested values also being allocated and initilased).

Assigning capabilities like this allows collaboration between the compiler and the runtime to construct and mutate values. However, the value of `c` can now change between one compile-time expression and the next and so we cannot 
use the value in later expressions. We can make concessions for capabilities that deny writes (for example `val`), such expressions can be bound to a name and re-used later; values with such capabilities can also be allocated as constant globals as there can be no data-race using them.

I have made a brief exploration into this approach and would like more discussion around its pros and cons.

### 2. Compile-time expressions are always val

The result of all compile-time expressions will be `val`. Making compile-time expressions result in a `val` value means that the we can use the value later on in the program. Consider the following:

```
class C1
  var x: U32 = 2

actor Main
  new create(env: Env) =>
    let c: C1 = # C1
    let x: U32 = # (c.x * 2)
    env.out.print(x.string())
```

In the above we can consider `c.x` to be a compile-time expression as `c` is compile-time constructed object and because it is `val` the value of `c.x` could not have changed since the object was constructed.

This means any expression to be evaluated at compile-time must be recoverable to `val`.

Making all compile-time expressions `val` allows the compiler to generate compile-time values as global constant values, one could imagine this permits more optimisations to be performed on the value.

Note: we can achieve (1.) by providing a `clone()` method on objects that we want to be constructed at compile-time and then `clone()` the global instance to get a local mutable copy.

I personally prefer (2.), this most closesly matches how string literals are implemented.

##Language Semantics

There is some discussion to be had about whether we can introduce new semantics to the language using compile-time expressions. An example of new semantics considers how a compiler handles the `error` expression; take the following snippet:
```
actor Main
  fun check(x: U32): U32 ? => if x < 10 then error else x end

  new create(env: Env) =>
    # check(3)
```
Here, we have some method `check` that is partial. I propose we can do one of two things here:
1. Allow the compile-time expression `check(3)` to resolve to an `error` (in this case we would need to wrap this is a `try` block).
2. Stop compilation with an error that a compile-time expression resulted in an `error`.

Option (2.) extends what we can do with `error` by making assertions at compile-time; this also has the effect that we don't need a `try` block around `check(3)` as the compiler as already garuanted that we don't need it and that `create` does not need to handle `error`s.

There may be more scope for considering how we can use compile-time expressions to extend the semantics of the language and this is an interesting point.

###Target Specific Behaviour

The results of a compile-time expression must match up to the result of the expressions, were the expression evaluated on the target machine. Evaluating expressions for the target introduces some complexity as they will be evaluated on the host machine. To ensure evaluation is correct, it must be arranged that whatever is responisble for evaluating expressions is aware of data types used for the target machine, for example the size of `USize`.

###Evaluating Compile-Time Expressions

A point of detail that must be considered is how compile-time expressions are to be evaluated. I suggest a new pass that runs after the `expr` pass.

# How We Teach This

The following new terms to consider are:
- "compile-time expression": an expression that will be evaluated at compile-time.
- "bind a value": this is a term I have been using to describe when a compile-time value is assigned to a `let` variable so that it can be used in later compile-time expressions. From example in `let x: U32 = # 4`, `4` has been bound to `x`.

This would make changes to the existing pony language, it would only extend the language.

The feature can be taught by explaining that the runtime and compile-time semantics of expressions match, so placing a `#` in front of an expression means the expression is evaluated at compile-time. The most important thing to teach would be the limitiations (this includes what is currently supported by the pony compiler). Namely:
- No compile-time actors and behaviours

# Drawbacks

Any expression that is evaluated at compile-time adds to the compilation time and will not (likely) be more efficient than executing at runtime. Conversely, this means there is less to execute at runtime and therefore saves time on every run of the program. This is a trade off that the developer will have to make as they see fit.

Evaluating compile-time expressions adds a significant amount of complexity and code to the compiler

We also need to ensure that compile-time semantics and run-time semantics agree (this is to avoid confusing bugs where different results are obtained).

Recall that I suggested that compile-time evaluation is done as an AST rewriting step. Making reference to target specific information, this means that we have to construct information about the target machine earlier than code generation.

# Alternatives

Most of the functionailty described through this RFC can be achieved by doing all of the computation at runtime. I can't really think of what an alternative to a compile-time expression would be, other than hoping constant propagation during optimisation does some of this work. I am interested to hear or discuss what an alternative would be to compile-time expressions.

One alternative to a design choice is making this an opt-in feature, instead allowing the compiler to figure out and evaluate what it can do at compile-time. This is quite compilicated, for example some expressions may have to make many function calls are execute for a very long time before we know whether it can be evaluated at compile-time. Attempting to determine whether something can be evaluated at compile-time becomes similar to trying to evaluate the expression. Ofcourse this could be a natural progression from being an opt-in feature, which I think is how this feature should at least start.

How the expressions are to be evaulated has multiple solutions; I suggest (and have implemented) an AST collapsing pass that takes an AST tree an collapses it to a single node. Adding the evaluation of a new pass allows the passs to make use of all the information and knowledge already in the compiler, such as parsing and symbol tables etc.

One could imagine alternative implementations such as building an interepreter and calling out to this, or constructing machine code on the fly and executing it to get a result. The latter approaches seem fairly convoluted and onerous to implement compared to AST rewriting.

# Unresolved questions

I've tried to mention questions as and when they are relevant in this RFC so please find them in the above. There is plenty of scope for discussion on most points.

If you are interested in exploring this feature please look at my current implementation of compile-time expressions [here|https://github.com/lukecheeseman/ponyc]

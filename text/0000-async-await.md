- Feature Name: Support async / await syntax sugar on top of promises
- Start Date: 2019-03-02
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Promises are very useful to facilitate the management of asynchronous behaviour, but working with them can quickly become tedious and error-prone.

Many programming language communities (JavaScript, Dart, Rust, C#, F#,Python, Scala, Kotlin) have recognized this problem and converged on the async/await construct.

# Motivation

Pony is quite different from most programming languages that are widely used by today's programmers. For this reason, Pony already offers many difficult challenges which may put off a large amount of programmers who could otherwise become active members of the community and contribute to the language's success.

One of the difficulties in Pony is no doubt working with asynchronous behaviours. Promises help a lot in that regard, but their usage can easily degenerate into what some people have termed the "callback hell", which makes it much harder to reason about the flow of a program.

The async / await pattern makes working with asynchronous code, and specially reasoning about it, much easier. Given that many programmers are already familiar with the concept, introducing it to Pony should help ease the learning curve of the language quite significantly without impacting negatively its overall design and performance.

# Detailed design

The async / await pattern can be implemented as syntax sugar by the compiler because the Pony Programming Language already supports:

* lambdas which can capture some of the scope surrounding it (explicitly).
* asynchronous computation that uses lambdas to continue the flow of execution (as promises do in Pony) at some point in the future.

The reason why these pre-conditions are enought is that they allow the automated translation of code as follows, (assuming `async fun` are functions that can use behaviours to return a value computed asynchronously, in the form of a `Promise`):

```
async fun lambdaV(t: T): Promise[V] => ...
async fun lambdaW(v: V): Promise[W] => ...

async fun async_fun(): Promise[W] =>
    let promise: Promise[T] = /* obtained from an async call */
    let t: T = await promise
    let v: V = await lambdaV(t)
    let w: W = await lambdaW(v)
    // from the point of view of the caller,
    this is a Promise[W] because this "fun" is marked as "async"
    w 
```

To:

```pony
async fun lambdaV(t: T): Promise[V] => ...
async fun lambdaW(v: V): Promise[W] => ...

fun async_fun(): Promise[W] =>
    let promise: Promise[T] = /* obtained from an async call */
    let result: Promise[W] =
        promise.next[V]({(t: T) => lambdaV(t)})
            .next[W]({(v: V) => lambdaW(v)})
    result
```

As the example above shows, each `await` call can be translated automatically into a promise chain. This translation would only occur in functions marked `async`, as above.

`async` functions are **not** functions that run, themselves, in another `Actor`, but they would presumably call an Actor's behaviour to perform asynchronus computation, returning a `Promise` instance passed to the called behaviour(s), as in the following example:

```pony
Actor Foo
    be compute(p: Promise[T]) =>
        let t: T = /* compute a value */
        p(t)

class Bar
    async fun bar(): Promise[V] =>
        let p = Promise[T]
        Foo.compute(p)
        let t: T = await p
        create_v(t)
    
    fun create_v(t): V =>
        let v: V = /* compute V */
        v
```

> Future work might look at allowing behaviours to return `Promise` instances to make the above pattern and async / await even more friendly.

There are some challenges regarding the capture of the lexical scope by the lambdas, but they can be solved by following the same rules as for lambdas: all captures must be explicit.

Therefore, in the case of `await` calls, a capture would look similar to lambda calls:

```pony
class Foo
    new create(env: Env, p: Promise[T]) =>
        let t: T = await(env) p
        // env can be used here as it was capture above
        t.use(env)
```

De-sugared to Promises and lambdas, this would become:

```pony
class Foo
    new create(env: Env, p: Promise[T]) =>
        p.next[None]({(t: T)(env) =>
            // env can be used here as it was capture above
            t.use(env)
        })
```

The implementation of this feature, for the above reasons, can and should be limited to the compiler's de-sugaring phase, without any other changes required.

## Limitations

`async` should be limited to function bodies only, not including constructors. Even though the single abstraction of asynchronous computation will continue to be Actor's behaviours, this limitation is necessary because:

* the feature remains opt-in, so programmers have a choice on whehter they want to use it.
* it is necessary to enforce that `async` functions return a `Promise` and no other types are allowed.
* it should help avoid slowing down the compiler as most functions presumably will not be marked `async`.
* behaviours cannot currently return values, so this feature doesn't make sense for them.

# How We Teach This

Because several popular languages have already introduced this pattern, the terminology used to describe it is pretty well established already. However, some of the terminology does not apply in Pony as well as it does in other languages.

For example, async / await is commonly described as follows (taken from the [Wikipedia article](https://en.wikipedia.org/wiki/Async/await)):

```
... the async/await pattern is a syntactic feature of many programming languages that allows an asynchronous, non-blocking function to be structured in a way similar to an ordinary synchronous function.
```

what "blocking" and "non-blocking" mean may not be clear to everyone in the context of the Pony runtime. It may be best to avoid using such language, preferring only synchronous VS asynchronous execution.

A call to `await` absolutely does not mean to block, it simply means to give up execution to another actor, a `Promise`, until it calls back (or errors, or even never) and executes the remaining of the body of the function (which is really, just a lambda inside the body of the function). This is why `async` functions are not allowed to return anything but a `Promise`.

It may help to have a tool, perhaps in the compiler itself, to expand async functions into their de-sugared version, similarly to how there are tools that expand macros in languages that support them.

No other parts of the language are affected by this change except the assumption that the body of a function always runs to completion before any other behaviour or function can execute in the same class or Actor. However, as the assumption still holds in the de-sugared case, explaining this exception in the documentation regarding only this feature should be enough to avoid confusion.

# How We Test This

The changes required to implement this feature, being restricted to the de-sugaring logic of the compiler, is fairly easy to test as it does not even require executing compiled programs.

Tests should include:

* `await` must not be recognized as a keyword outside of `async` functions.
* only functions may be marked with `async`.
* `async` functions must have `Promise` as a return type.
* the return value of the function is always automatically wrapped into a `Promise`.
  This implies that if an `async` function returns a value of type `Promise[T]`, its return type must be `Promise[Promise[T]].
* compiler error messages in sugared code should take into account the fact that the error won't match the source.
* nested promises can be handled (e.g. `let v: V = await await p` is valid).

# Drawbacks

This feature is quite simple to use, but some people may face issues related to reasoning about which part of the code is run sequentially, and which part is not. This is already somewhat problematic in Pony since the introduction of lambdas, but the difficulty seems to be low.

The introduction of a lexical scope which is not separated visually from the surrounding scope (because of the introduction of implicit lambdas) is at the same time a big drawback and essential to make asynchronous code easier to read and write. As the Wikipedia description of the pattern says, the pattern makes it possible to structure asynchronous code similarly to ordinary synchronous code. The latter is without doubt easier to reason about. Due to the fact that reading and writing asynchronous code is central to Pony's proposition, making it easier for programmers should take precedence over comparatively minor comprehension issues (such as understanding the lexical scopes changes).

No existing code should break due to this feature because `async` functions do not yet exist.

# Alternatives

Composing asynchronous computations with Promises or Futures in a way that is easier to read and write than by using callbacks explicitly has been attempted previously by other languages.

For example, Go channels offer a different solution, though they could not be transferred to Pony due to the fact that receiving messages from channels necessarily blocks the caller's execution.

An older and similar technique is continuation passing, but experience shows that they tend to become even harder to read than commonly used promises today.

Some patterns have emerged within the Pony community that actually solve some problems with composing asynchronous computation. For example, it is possible to use an aggregator `Actor` to collect results from many parallel computations, then calling back when all results have been received, without using promises at all.

The problem is that, even though this kind of pattern may work well in many circumstances, it doesn't actually help with composing promises sequentially, only concurrently, and even then arguably in a way that is not nearly as easy to read as sequential async / await instructions.

# Unresolved questions

In order to make this pattern more easily usable in Pony, there would be a need to integrate the main asynchronous construct in Pony, Actor's behaviours, with Promises, so that behaviours would be able to return a value to a caller via a Promise (rather than having to be given the Promise to fullfill by the caller). This would be, however, a much bigger change that would involve runtime changes as well as a restructuration of the compiler, hence this was deemed to be out of scope for this RFC.

There may be some issues related to how the translation from sequential await calls to promise chains should be done, but due to the explicit nature of types declarations and lexical scope captures in Pony, these should not be very problematic.
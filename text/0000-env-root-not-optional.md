- Feature Name: env_root_not_optional
- Start Date: 2020-01-20
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

[`Env.root`](https://stdlib.ponylang.org/builtin-Env#let-root-ambientauth-val-none-val) currently has type `(AmbientAuth | None)` to allow for
creation of artificial `Env` instances without `AmbientAuth`.
Yet, there is no observable usage of this feature. 
As it is cumbersome to use, as on always needs a pattern match 
or an `as` expression with a surrounding `try`, 
this RFC wants to change its type to `AmbientAuth` and make `AmbientAuth` required when constructing
an artificial `Env` instance.

# Motivation

In a [discussion on Zulip](https://ponylang.zulipchat.com/#narrow/stream/189985-beginner-help/topic/Main.20boilerplate) it was mentioned that having to always use `as` with surrounding `try` or a pattern-match
for accessing `AmbientAuth` via [`Env.root`](https://stdlib.ponylang.org/builtin-Env#let-root-ambientauth-val-none-val) is cumbersome and it turned out the reason for this was
kind of hard to justify.

```pony

actor Main
  new create(env: Env) =>
    try
      let auth: AmbientAuth = env.root as AmbientAuth
      // do something with auth
    else
      env.err.print("no auth available.")
      env.exitcode(1)
    end
```

```pony
actor Main
  new create(env: Env) =>
    match env.root
    | let auth: AmbientAuth =>
      // do something with auth
    else
      env.err.print("no auth available.")
      env.exitcode(1)
    end

[`Env.root`](https://stdlib.ponylang.org/builtin-Env#let-root-ambientauth-val-none-val) is of type `(AmbientAuth | None)`
and can thus possibly be `None`. This is for enabling people to create artificial `Env` instances that not need an `AmbientAuth` e.g. for testing
handling of stdout via `Env.out` or similar things.

But after searching for usages of artificial `Env` instances, it turned out, this feature is actually not used at all.
There might be several reasons for this:

 * Pieces of code that use command line arguments, environment variables, out-streams or other members of `Env` take those in their constructor or methods
   and artificial instances of those can be easily used for testing without an artificial `Env`.
 * There might be no need to use an artificial env without `AmbientAuth` as we have `Env` available in ponytest
   anyways via [`TestHelper.env`](https://stdlib.ponylang.org/ponytest-TestHelper#let-env-env-val), including `AmbientAuth`.

In the light of this, it seems more reasonable to optimize for convenience of usage in the normal case than
designing for possible use cases, that are actually not used at all, at the price of added ceremony/boilerplate.

It might be desired to control what kind of control a pony process is started with (maybe it is not allowed to write to the filesystem) or
to actually give no auth at all to the process via some cli flag and some runtime code, determining what kind of auth to put into `env.root`.
But this change requires a more substantial change to both `Env` and the runtime, so this might be left for some future version of pony
and this broader idea should not interfere with what this RFC is suggesting.

# Detailed design

Make [`Env.root`](https://stdlib.ponylang.org/builtin-Env#let-root-ambientauth-val-none-val) have type `AmbientAuth`
and change [`Env.create`](https://stdlib.ponylang.org/builtin-Env/#create) to take an `AmbientAuth` for the `root'` parameter,
thus require `AmbientAuth` when creating an artifical instance of `Env`.

# How We Teach This

Next to substantial changes in stdlib documentation and tutorial, examples and patterns, adapting the examples to how `Env.root` can be accessed now, 
a small change in the docstrings of `Env`, correcting how to create an `Env` should be enough.

# How We Test This

# Drawbacks

* Breaks existing code
* Makes creating artificial `Env` instances a little harder.

# Alternatives

Just accept the way it is now. This only affects short examples in a bad way, not big code bases.
Those check for the `AmbientAuth` once in `Main.create`, exit with `1` and are done with it. The rest of the codebase
usually is not concerned with this tiny boilerplate. Just chill and pony on.

Ignore this RFC and go for the big picture already, introducing dynamic `auth` provided to the process
at start time (similar to linux capabilities) via cli flag. Make it possible to explicitly grant or deny certain capabilities 
(not to be confused with reference capabilities) by making certain `Auth` instances available or not.

# Unresolved questions


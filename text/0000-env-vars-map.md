- Feature Name: env-vars-map
- Start Date: 2019-03-02
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Environment variables corresponding values should be exposed via a `Map` in
`Env`.

# Motivation

Just about every programming supports accessing environment variables via some
method of lookup - either via a function or a data structure.

Currently in Pony, the program's environment is provided as `Array[String] val`
via `Env.vars` on which the user has to iterate and perform some string
operations in order to a) check if an environment variable was specificied and
b) check its corresponding value.

The current method of checking and retrieving an environment variable's value is
duplicated in every Pony program that requires such functionality. Let's move
this into the standard library so users can easily access environment variables
and their values.

# Detailed design

`Env` would be modified to have a public field `vars_map: Map[String, String]
val` and in constructors this map would be created to reflect the key-value
pairs present in `vars: Array[String] val`.

# How We Teach This

This new addition can be publicized in the next release's changelog.

# How We Test This

A code review should be sufficient as the implementation is trivial.

However, tests can be written to ensure that the contents of `Env.vars`' are
indeed present in `Env.vars_map`.

# Drawbacks

Introducing this change means users now have two ways to access environment
variables.

# Alternatives

The alternative is to not implement this.

# Unresolved questions

As mentioned in [#Drawbacks](Drawbacks) there would now be two ways of accessing
environment variables which seems questionable. Perhaps a future RFC can
introduce the deprecation of `Env.vars` or perhaps even its removal so that
there is only one simple way of accessing environment variables.

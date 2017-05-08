- Feature Name: Method must refer to trait or interface
- Start Date: 2016-09-07
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Public methods on an actor or class must implement a declared trait or help complete an interface.

# Motivation

Since Pony is a statically-typed language, it makes sense to understands its OOP approach as contract-based. This allows the compiler to help the programmer write correct programs.

In Pony, contracts are defined through traits and interfaces. The compiler validates objects against these, but it doesn't check if objects implement more than what's in the contract (this applies for both traits and interfaces.)

Java optionally provides the ``@Override`` annotation to require that a method overrides a method defined in a superclass and the same annotation can be used (rather confusingly) to require that a method implements a method in a declared trait (but again, the annotation is optional.)

This proposal is for a requirement that all methods defined on a class or actor match a trait definition, or help complete an interface. With this requirement there is no need for an annotation such as Java's ``@Override``.

# Detailed design

The compiler will support a new flag ``-Wpedantic`` (enabled in Pony's own test suite and encouraged in general) that enables the proposed validation.

Note that the requirement only affects public methods (those that do not begin with an underscore).

# How We Teach This

OOP needs to be talked about in the tutorial. That is, what is Pony's understanding of OOP and how it's different from Smalltalk and other duck-typed OOP languages.

In Erlang, an actor is allowed to ignore incoming messages. This is not how Pony works. In Pony, an actor messages are methods and are type-checked just like object methods.

# Drawbacks

Currently none have been identified.

# Alternatives

As presented in the motivation previously, Java handles these concerns differently: with an optional annotation that the compiler is able to validate.

# Unresolved questions

The impact on existing code is currently not known.

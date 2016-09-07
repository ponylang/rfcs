- Feature Name: Method must refer to trait or interface
- Start Date: 2016-09-07
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

A public method on an actor or class should match a declared interface or contribute to a trait.

# Motivation

Since Pony is a statically-typed language, it makes sense to understands its OOP approach as contract-based. This allows the compiler to help the programmer write correct programs.

In Pony, contracts are defined through traits and interfaces. The compiler validates objects against these, but it doesn't check if objects implements more than what's in the contract.

This means that the contract can be changed with the implementation left out of sync.

Java optionally provides the ``@Override`` annotation to require that a method overrides a method defined in a superclass and the same annotation can be used (rather confusingly) to require that a method implements a method in a declared interface (but again, the annotation is optional.)

This proposal is for a requirement that all methods defined on a class or actor match an interface definition, or help complete a trait. With this requirement there is no need for an annotation such as Java's ``@Override``.

# Detailed design

A method is allowed if it implements a method from a declared interface, or if it helps complete a trait – in any other case, it's a compile-time error.

The requirement only affects public methods (those that do not begin with an underscore).

# How We Teach This

OOP needs to be talked about in the tutorial. That is, what is Pony's
understanding of OOP and how it's different from Smalltalk and other
duck-typed OOP languages.

In Erlang, an actor is allowed to ignore incoming messages. This is
not how Pony works.

# Drawbacks

Currently none have been identified.

# Alternatives

As presented in the motivation previously, Java handles these concerns differently: with an optional annotation that the compiler is able to validate.

# Unresolved questions

The impact on existing code is currently not known.

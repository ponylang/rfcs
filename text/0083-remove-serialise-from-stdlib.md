- Feature Name: remove-serialise-package-from-stdlib
- Start Date: 2026-03-27
- RFC PR: https://github.com/ponylang/rfcs/pull/225
- Pony Issue: https://github.com/ponylang/ponyc/issues/

# Summary

Remove the `serialise` package from the standard library.

# Motivation

The `serialise` package is a security footgun. It's only safe when used with fully trusted data. Deserializing untrusted data can crash the program or, worse, give hostile code unauthorized access to the machine. There's no verification pass to check that a deserialized object graph is well-formed. Arbitrary bytes get interpreted directly as Pony heap objects.

This isn't a bug in the implementation. It's fundamental to how the package works. The capability tokens (`SerialiseAuth`, `DeserialiseAuth`, etc.) gate access to the functionality, but they do nothing to make deserialization of untrusted data safe.

The package came up during work to remove `pony_error` (ponylang/ponyc#5002). `serialise` depends on runtime code that uses `pony_error`, and updating it to work without `pony_error` is an unknown amount of effort. Given the security issues, that effort isn't justified. Rather than invest in a package with fundamental safety problems, the better path is to remove it.

No other standard library package depends on `serialise`. It's entirely standalone.

# Detailed design

Remove the `serialise` folder from `ponyc/packages` and remove mention of it from `ponyc/packages/stdlib/_test.pony`.

# How We Teach This

In the release notes for the ponyc version that removes `serialise`, explain why the removal was done. Users who depend on it will need to implement their own serialization.

# How We Test This

ponyc will pass CI testing after the removal.

# Drawbacks

This will break existing code that uses the `serialise` package.

# Alternatives

- Leave the package in the standard library and update it to work without `pony_error`. The amount of effort required is unknown.

# Unresolved questions

None.

- Feature Name: builtin-ffi-safe-only-as-default
- Start Date: 2022-01-15
- RFC PR:
- Pony Issue:

# Summary

The current default is to allow FFI calls from any package. The optional `--safe` flag takes an argument of a colon delimited list of packages and limits FFI calls to those and `builtin`.

The purpose of this RFC is three-fold:

* Change default from "allow all" to "deny all except stdlib"
* Rename the `--safe` flag to the more explicit `--allow-ffi`
* Provide an error message should a non-existent package be in the allow-list


# Motivation

Object Capabilities, Referencial Capabilities, and Type-Safety are how the pony compiler provides its guarantees. FFI calls bypass the pony compiler's checks allowing third party packages be able to make FFI calls. This is an unsafe default.

If a package requires FFI then the user should be explicitly aware that this is the case.  By mandating the user acknowledge this with the `--allow-ffi` flag, we have confirmed they are aware and have had the opportunity to do their due diligence or forgo its use completely.

An error should be raised if a non-existant package is in the pre-compiled "stdlib allow-list" or provided to `--allow-ffi` to ensure that if in the future we remove an approved library from stdlib and forget to remove it from the allow-list then it does not create a namespace that can be exploited.


# Detailed design

stdlib is not builtin so the packages that are in stdlib will need to be enumerated in the allow-list.

* assert
* backpressure
* builtin
* capsicum
* collections
* debug
* files
* format
* net
* ponybench
* ponytest
* process
* term
* time
* serialise
* signals

We should not add to the allow-list packages not in stdlib but still maintained by ponylang as there is no guarantee at compile-time that the "regex" package the user has in their tree is the one from ponylang.


# How We Teach This

The packages section should mention that packages may request FFI access and a top-level description of what that means.

The FFI section should mention the flag requirement if your FFI calls are in a package (and a reminder to document it)


# How We Test This

Our existing tests should cover if we break any existing functionality.

Some of our existing tests use FFI so will need their build flags modified to allow them to compile.


# Drawbacks

* Breaks existing code which uses non-stdlib packages that use FFI.


# Alternatives

Keep things as they are with the default that any package can make FFI calls.


# Unresolved questions

Should there be an option for `--allow-ffi=*`?


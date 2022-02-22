- Feature Name: Remove logger package from standard library
- Start Date: 2022-02-04
- RFC PR: https://github.com/ponylang/rfcs/pull/198
- Pony Issue: https://github.com/ponylang/ponyc/issues/4030

# Summary

Remove the logger package from the standard library and move to its own library under the ponylang org.

# Motivation

The logger library that I wrote and added to the Pony standard library is intentionally limited in its functionality and leans heavily into reducing messaging overhead between actors to the point of intentionally sacrificing functionality.

Our stated belief as a core team has been that the standard library isn't "batteries included". We have also stated that libraries were we believe it would be "relatively easy" for multiple competing standards to appear in the community shouldn't be included in the standard library unless other factors make inclusion important.

Some other factor we have discussed in the past include:

- Not having a standard library version would make interop between different 3rd-party Pony libraries difficult.
- The functionality is required or called for by an interface in one or more standard library classes.
- We consider the having the functionality provided to be core to the "getting started with Pony experience".

I don't believe that any of above 3 points apply to the `logger` package.

# Detailed design

The logger package isn't integrated at all into the rest of the standard library. It's removal involves removing the `logger` folder from `ponyc/packages`. And removing mention of it `ponyc/stdlib/_test.pony`.

Before removal, we will first create a new repository under the `ponylang` GitHub organization. It will be set up to match our standard convention for library repository organization.

Once the repository is set up, we will release version 1.0.0 of the Ponylang "logger" library and announce it via the channels already handled by our release process scripts.

The full extent of know ponyc repository changes needed to remove `logger` and get CI passing is available on the `remove-logger-from-stdlib` branch in the `ponylang/ponyc` repository.

# How We Teach This

The change will be made public via:

- RFC announcements in LWIP
- Release notes when the version of ponyc that removes `logger` is released including information about where to get the independent version of the library and how to update code
- LWIP announcing the new library's creation
- LWIP announcing the 1.0.0 version of the new logger library

# How We Test This

ponyc will pass CI testing after the removal. The new logger library will have the same tests as currently exist in the standard library

# Drawbacks

This will break any existing applications that are using the logger package. Updating will be straightforward as long as the application is using corral. Updating without corral will be a little more work.

The breakage is minimal, but it still needs to be noted that this will break any pony code that uses `logger` as part of the standard library.

# Alternatives

- Keep the status quo
- Remove the logger library from the standard library but don't maintain as a ponylang library

# Unresolved questions

None

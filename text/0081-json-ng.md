- Feature Name: json-ng
- Start Date: 2026-02-14
- RFC PR: https://github.com/ponylang/rfcs/pull/219
- Pony Issue: https://github.com/ponylang/ponyc/issues/4924

# Summary

Add [json-ng](https://github.com/ponylang/json-ng) to the standard library.

# Motivation

Several years ago, we [removed `json` from the standard library](https://github.com/ponylang/rfcs/blob/main/text/0078-remove-json-package-from-stdlib.md). The library was a regular source of difficulty. It was painful to use and didn't give a lot of value. There weren't a lot of good reasons to keep it in the standard library.

We recently moved the Pony langauge server from its own repo into the ponyc repo. There were a number of very good technical reasons for doing this. It was the first time we put a "related tool" in the ponyc repo and it raised some questions.

pony-lsp has dependencies on Pony code from outside the standard library. In particular, Matthias' immutable-json library and his pony-ast library. We have "vendored" those libraries into ponyc but keeping them up-to-date is going to be painful. When we did this vendoring, we did it with the express idea of "replacing" those vendored dependencies. The ponyc repo shouldn't be depending on other ponylang or 3rd party repositories for pony code. Everything should be in the standard library. That is the decision we made and I think it is a good decision.

The inclusion of json-ng in the standard library will remove the need for the vendored dependency for pony-lsp. It will give us a solid JSON library to use on other ponyc adjacent tools as we add them to the distribution and it's also a really nice library.

It takes lessons learned from Matthias' immutable-json. From Patrocles' jay. From Joe's pony-jason. And inspiration from JSON libraries in other languages and combines them into a solid library that can serve multiple use cases.

# Detailed design

https://github.com/ponylang/ponyc/issues/4833 needs to be merged before this RFC happens and JSONNull changed to None.
 
## json-ng

From https://github.com/ponylang/json-ng we will move the following into the ponyc repo.

- `json` will be moved into the standard library's packages as `json`
- `packages/stdlib/_test.pony` will be updated to call the `json/_test.pony`
- `examples/basic/main.pony` will move to `examples/json/main.pony`

Additionally:

- Add a README.md to `examples/json`
- Add a .gitignore to `examples/json`

Any references to `json-ng` in anything that is moving will be changed to `json`.

Finally, the json-ng repository will have its README updated to note that it has been included in the standard library and the repo will be archived.

## iregex

The json-ng library contains a private iregex library use to support the JSONPath functionality. We will make the iregex functionality public and include it in the standard library.

The new json library will need to be updated to use the now public iregex. The private iregex implementation will have been moved at this point.

## ponylang/json

ponylang/json should have its README updated to point to the new json library in the standard library. The repository should be archived. The packages list on the website should have ponylang/json removed.

# How We Teach This

The inclusion will be announced via Last Week in Pony.

Users will be able to learn to use via the documentation that is part of json-ng. There's reasonably extensive docstrings along with the example that should be able to get any experienced Pony programmer going.

# How We Test This

All tests moved over from json-ng should pass and the example should compile. Basically, we have CI. The plan involves hooking json-ng into that CI when it moves. The ponyc CI should pass.

# Drawbacks

I don't see drawbacks here. I think json-ng combines the best of what folks have come up with for JSON handling in Pony over the years. But, if there are drawbacks that people come up with during the RFC process, we can include them here.

# Alternatives

We could design a different library. We already decided when we moved pony-lsp into ponyc that we were going to include a JSON library in the standard library. The question now is, is this the right one?

# Unresolved questions

None

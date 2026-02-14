- Feature Name: json-ng
- Start Date: 2026-02-14
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Add [json-ng](https://github.com/ponylang/json-ng) to the standard library.

# Motivation

Several years ago, we [removed `json` from the standard library](https://github.com/ponylang/rfcs/blob/main/text/0078-remove-json-package-from-stdlib.md). The library was a regular source of difficulty. It was painful to use and didn't give a lot of value. There weren't a lot of good reasons to keep it in the standard library.

We recently moved the Pony langauge server from its own repo into the ponyc repo. There were a number of very good technical reasons for doing this. It was the first time we put a "related tool" in the ponyc repo and it raised some questions.

pony-lsp has dependencies on Pony code from outside the standard library. In particular, Matthias' immutable-json library and his pony-ast library. We have "vendored" those libraries into ponyc but keeping them up-to-date is going to be painful. When we did this vendoring, we did it with the express idea of "replacing" those vendored dependencies. The ponyc repo shouldn't be depending on other ponylang or 3rd party repositories for pony code. Everything should be in the standard library. That is the decision we made and I think it is a good decision.

The inclusion of json-ng in the standard library will remove the need for the vendored dependency for pony-lsp. It will give us a solid JSON library to use on other ponyc adjacent tools as we add them to the distribution and it's also a really nice library.

It takes lessons learned from Matthias' immutable-json. From Patrocles' jay. From Joe's pony-jason. And inspiration from JSON libraries in other languages and combines them into a solid library that can serve multiple use cases.

# Detailed design

## json-ng

From https://github.com/ponylang/json-ng we will move the following into the ponyc repo.

- `json` will be moved into the standard library's packages as `json`
- `packages/stdlib/_test.pony` will be updated to call the `json/_test.pony`
- `examples/basic/main.pony` will move to `examples/json/main.pony`

Additionally:

- Add a README.md to `examples/json`
- Add a .gitignore to `examples/json`

Finally, the json-ng repository will have its README updated to note that it has been included in the standard library and the repo will be archived.

## ponylang/json

ponylang/json should have its README updated to point to the new json library in the standard library. The repository should be archived. The packages list on the website should have ponylang/json removed.

# How We Teach This

The inclusion will be announced via Last Week in Pony.

Users will be able to learn to use via the documentation that is part of json-ng. There's reasonably extension docstrings along with the example that should be able to get any experienced Pony programmer going.

# How We Test This

All tests moved over from json-ng should pass and the example should compile. Basically, we have CI. The plan involves hooking json-ng into that CI when it moves. The ponyc CI should pass.

# Drawbacks

I don't see drawbacks here. I think json-ng combines the best of what folks have come up with for JSON handling in Pony over the years. But, if there are drawbacks that people come up with during the RFC process, we can include them here.

# Alternatives

We could design a different library. We already decided when we moved pony-lsp into ponyc that we were going to include a JSON library in the standard library. The question now is, is this the right one?

Assuming we go forward with this RFC, we should consider extracting the IRegex library that is private to json-ng into a package that can live as its own package in the standard library. This would provide basic regex capabilities in the standard library without any dependencies on external libraries.

Lastly, we should discuss https://github.com/ponylang/ponyc/issues/4833 and if we want to address that. If we do, there would be a small change to json-ng that ideally, we want to do before it is moved into the standard library. At the moment, it has a JsonNull type that could be swapped out for None. We can't use None at the moment as it conflicts with the None used in the persistent HashMap.

# Unresolved questions

Should IRegex support remain private to json-ng or should it be extracted to its own package after json-ng is incorporated into the standard library.

- Feature Name: Add ponycheck to the standard library
- Start Date: 2022-02-02
- RFC PR: https://github.com/ponylang/rfcs/pull/197
- Pony Issue: https://github.com/ponylang/ponyc/issues/4029

# Summary

Add [ponycheck](https://github.com/ponylang/ponycheck) to the Pony standard library.

# Motivation

My motivation for this RFC is twofold:

## I would like to make property based testing more prevalent in the Pony community

I believe that by including a property based testing package in the standard library that more people are likely to discover and use it. I am always wary of adding libraries to the standard library as it can discourage 3rd-party efforts. Writing a property based testing package is a lot of work and so far, ponycheck is the only implementation for Pony. Given the lack of current alternatives and the amount of work it would take to write an alternative, I believe that it is reasonable to assume that we are unlikely to impede the growth of a pony testing ecosystem with this change.

## I would like to be able to use property based testing in the standard library

It isn't currently possible to do any property based testing in the standard library. I believe our test coverage could be improved going forward if property based testing was available as an option.

# Detailed design

From the [ponycheck repository](https://github.com/ponylang/ponycheck):

- Add the `ponycheck` package as a new package in the top-level of the standard library
- Add the example test application in `examples` to a new folder `examples/ponycheck` in the ponyc repo. The `examples` should follow the README usage already in place for each README in the ponyc repo.
- Review the content in `README` to see what if any should form the basis of a section on ponycheck in the tutorial (see more below). The README contains similar content to what is already in the generated package documentation which I believe can stay the same so it is possible that in addition to taking content from the README, we might want to also crib from the package level documentation.
- Update the README to announce that ponycheck has become part of the pony standard library and then archive the repository so that it is read only.
- Transfer `ponycheck` repo issues to the `ponyc` repo

I think it is important to note as part of this design that ponycheck has no dependencies other than standard library so no additional packages need to be added to the standard library to support this change. I believe that for the sake of precedent that this should be noted as in the future, RFCs might be opened to include other packages in the standard library and those that would require bringing in additional dependencies should be vetted with even more caution than a single package/dependency free addition as advocated by this RFC.

# How We Teach This

Ponycheck's existing documentation would become part of the [standard library documentation site](https://stdlib.ponylang.io/).

The [testing section of the tutorial](https://tutorial.ponylang.io/testing/index.html) should have another page for "Testing with Ponycheck" added. The rubric for "is the new tutorial section through enough" should be "do we believe that it conveys at least as much information as the ponytest section currently does".

Beyond teaching, for letting people know about this change we should:

- Note the move in the README for the ponycheck repo and also note what previous users of ponycheck would need to do to adapt to the change.
- Announce the change in LWIP
- Include notice of the change and what a ponycheck user needs to be to adapt in the release notes for the ponyc version that includes ponycheck

# How We Test This

Existing ponycheck tests should be incorporated into the standard library tests.

# Drawbacks

The primary drawback would be that for many changes, ponycheck would need to go through the RFC process. This could in theory result in slower development, however, given the lack of recent development on ponycheck, that seems to be a theoretical rather than practical issue at the moment.

If ponycheck was included in the standard library, that might increase usage and the desire to add/change features and then the RFC issue might become problematic, but if ponycheck develop was "rebooted" due to inclusion in the standard library, it would be hard to complain about the results of that addition being problematic for future development.

One might argue that the maintenance burden of a package in the standard library is higher than one that is maintained by to ponylang org as an independent repository. I personally do not believe that to be the case, but I think it is worth including here as a "possible drawback". As the person who maintains most of the other ponylang repos and keeps the GitHub actions and other code in them up-to-date, I would argue that packages in the standard library have a net lower carrying cost for me as a primary Pony developer.

# Alternatives

- Leave ponycheck as an independent library.
- Conditionally accept ponycheck but not until certain features are implemented prior to becoming part of the standard library.
- Use an approach like [stdlib-properties](https://github.com/mfelsche/stdlib-properties) to use ponycheck to test the standard library without adding ponycheck to the standard library.

# Unresolved questions

When [discussed](https://ponylang.zulipchat.com/#narrow/stream/189959-RFCs/topic/ponycheck) in the Ponylang Zulip, the primary point of conversation resolved around the question of should the name "ponycheck" be changed.

This RFC suggests leaving the name as is for a few reasons including:

- no change for user code except to stop fetching ponycheck from the old independent repo
- my belief that given the existence of tools like "scalacheck" that "ponycheck" is a descriptive name

Some folks disagree that "ponycheck" is a descriptive name as part of the discussion for this RFC, we should decide if we want to keep ponycheck as the name.

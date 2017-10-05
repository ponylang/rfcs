- Feature Name: expose_ponyc_version
- Start Date: 2017-10-05
- RFC PR:
- Pony Issue:

# Summary

Ponyc's version will be exposed to a pony program, so the program could report the version of ponyc that it was built with.

# Motivation

This proposal will allow pony programs to access the ponyc version they were built with via a pony function. This will enable programs to include the ponyc version they were built with in their own version (if they were designed to report it), similarly to the way `ponyc --version` includes the version of LLVM it was compiled with.

# Detailed design

The version information already exists in the ponyc binary, since it can report its version and the compiler it was built with. This information could be exposed via a pony runtime function which would return a string of the ponyc version.
Optionally, an additional function could return a string of the LLVM version ponyc was compiled with.

# How We Teach This

This feature should include documentation in the standard library documentation, and it would be helpful to include an example of how to get the ponyc version in your application version in the pony patterns cookbook, and the pony tutorial.

# How We Test This

I don't think it can be tested as a unit test. It could be tested by comparing `ponyc --version` with a version printed from a pony application in `examples` that has a `--version` option. I am not sure whether this should be done manually or whether it should be automated via a script to run as part of the CI.

# Drawbacks

This would add more code that will need to be maintained.

# Alternatives

1. Use a runtime `--ponyversion` option, which would print the pony version and exit. I think this can be done entirely in `/src/libponyrt/sched/start.c`, and has the benefit that pony users do not need to change anything in their program, while still getting the benefit of being able to tell what ponyc version their program was compiled with.
2. Applications that use a build tool could execute `ponyc --version` to get the version and supply it as a constant in their application in some manner. This seems clunky and error prone.
3. Do not provide this feature.

# Unresolved questions

- How should PONY_VERSION be exposed to a pony program?
- What type should the version be provided as? (A single `String`, an `Array[String]`, a `Map[String, String]`, something else?)

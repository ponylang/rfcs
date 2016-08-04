- Feature Name: buffers
- Start Date: 2016-07-28
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

The ReadBuffer and WriteBuffer classes will be moved out of the net package of the standard library.

# Motivation

The uses of the ReadBuffer and WriteBuffer classes are useful to I/O outside of the net package, such as files. Therefore they should be seperated into a package that better reflects their general usefulness.

# Detailed design

Move the `ReadBuffer` and `WriteBuffer` classes into a new package called `buffered` and rename them to `Reader` and `Writer` respectively. They can then be accessed as `buffered.Reader` and `buffered.Writer`.

# How We Teach This

These classes will be more easily discovered in a `buffered` package than in the current `net` package. Other than the name changes, the documentation and APIs will remain unchanged.

# Drawbacks

- Existing code will break.

# Alternatives

- Keep the names `ReadBuffer` and `WriteBuffer` to continue the focus on unnamed imports

# Unresolved questions

None

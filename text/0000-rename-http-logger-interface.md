- Feature Name: rename-http-logger-interface
- Start Date: 2018-01-06
- RFC PR:
- Pony Issue:

# Summary

Rename `interface val Logger` in the `net/http` stdlib package to `interface val HTTPLogger`.

# Motivation

Different libraries in the stdlib are (usually) expected by users of Pony to be conflict-free, without the use of aliases. However, the interface `Logger` in `net/http` currently clashes with the class `Logger` in `logger`. This means that the following code currently leads to an error regarding "existing type name classes" on compilation:

```pony
use "logger"
use "net/http"

actor Main
  new create(env: Env) =>
    None
```

# Detailed design

As a matter of "principle of least surprise", the class in `logger` should remain named as `Logger`. This arises from the fact that the class provides a bulk of the core functionality of its homonymous package.

Therefore, all uses of the `Logger` interface within and on uses of the `net/http` library should be renamed to `HTTPLogger`.

This will allow for both packages to be used simultaneously in Pony programs, without any aliases.

# How We Teach This

The name of this interface will be updated in the stdlib documentation.

# How We Test This

Current `net/http` tests being run on CI should not break once all instances of the interface are renamed.

# Drawbacks

* Breaks any existing code that calls this interface explicitly, although the fix should be simple by following the updated docs.
* Adds verbosity to the type name.

# Alternatives

Do not update the interface name, and instruct users to use a package alias as instructed in the Pony Tutorial.

# Unresolved questions

None.

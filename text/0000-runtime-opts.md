- Feature Name: runtime-opts
- Start Date: 2019-11-02
- RFC PR: 
- Pony Issue: 

# Summary

This feature is a proposal to consolidate how we deal with these options, providing a way to avoid colissions with user defined options, upgrade and deprecation path across Pony releases. 

# Motivation

The options (`--pony*`) provided to a compiled Pony program to control its runtime environment have evolved overtime, with the latest instance being the `--ponythreads` to `--ponymaxthreads` [rename](https://github.com/ponylang/ponyc/issues/3318). With the current approach, this change would silently ignore the old option. It could possibly fail further parsing within user's application, as recognized `--pony*` arguments are _not_ exposed through `Env.args` the old, yet the now "unused" option would be exposed.
The opposite being just as true: a user specified option could be elided if the runtime would consume it in a subsequent release. Nothing prohibits a user from using the `--pony` prefix. 

# Detailed design

Building upon [RFC-0064](0064-llvm-cli-opts-integration.md), as we probably should avoid introducing a new pattern, the proposal is to have a single option, namely `--pony_opts`, to pass all options as a single, comma seperated string, for the runtime to consume, e.g.:

```
$ ./helloworld --pony_opts="minthreads=2,pin,maxthreads=4" 
Hello, world.
```

Providing an unknown "key" within that string would result in an error:

```
$ ./helloworld --pony_opts="minthreads=2,pin,maxthreads=4,answer=42" 
Unrecognized option answer, see --pony_opts=help for more information
$ echo $?
255
```

Also enabling for deprecation by providing a warning (on stderr?):

```
$ ./helloworld --pony_opts="minthreads=2,pin,threads=4" 
Warning: the --pony_opts threads was renamed to maxthreads
Hello, world.
```

### Fill all the "other" details in!

# How We Teach This

By updating the documentation, as we've done so far with these changes. But once that change is in we'll fail early when unrecognized options are passed to the runtime, while providing a consistent experience for the executed program.

# How We Test This

I won't say "just as we do now", as... well, we currently don't! Formalizing this seems like the very time where we'd need to have proper test coverage to specify this behavior. That being said, proper unit test coverage should be all that's needed™. 

# Drawbacks

The character for delimiting each runtime option is a problem this solution introduces. 

# Alternatives

## Namespacing

The `pony` prefix seems to be an agreed upon way to “qualify” arguments meant to be targeted to the runtime (GC, scheduler et al). Making `pony` an explicit namespace for the runtime to _consume_ all arguments in it. I'd make it explicit with a separator, (e.g. `:` , resulting in arguments in the fully qualified form of `--pony:maxthreads=3`, and making sure all passed arguments are recognized as valid arguments by the runtime.
This provides a way forward for deprecation as well, as:
 * The new name is definitively available, as nothing is the pony: namespace ever gets exposed to the hosted program;
 * We can keep easily add aliasing, then warn and finally remove the “deprecated” name entirely over multiple releases.

## One environment variable

Having multiple come with the same downside as what we currently have. So we could pass the string to be parsed as an environment variable instead of an argument to the executable.

# Unresolved questions

The delimiter is, just as in [RFC-0064](0064-llvm-cli-opts-integration.md), an obvious issue: what character, or sequence there of, is most likely not to be used in an actual value for all future options to come? And if we get it wrong how do we best escape it?

What do we do about `--ponyhelp` and `--ponyversion`? While these are useful and should probably stick around, they aren't like any other option, as they shortcircuit the actual program's execution.

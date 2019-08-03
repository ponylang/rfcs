- Feature Name: llvm-cli-opts-integration
- Start Date: 2019-08-03
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

The proposed feature allows users of `ponyc` to supply LLVM-specific command line options from `ponyc`'s command line interface in dev builds (i.e. Debug build). This should make development of `ponyc` easier by improving accessibilities of internal LLVM features during debugging and fine-grained tuning.

# Motivation

`ponyc` uses LLVM heavily for code optimizations and code generation. There are many cases where it requires developers to inspect some parts of the LLVM pipeline. For example, when debugging a crash induced by violation of LLVM's own verifier rules. It would be great to use LLVM's `-print-after-all` command line option to dump LLVM IR after each pass. However, currently there is no way to turn on this option directly from `ponyc`'s command line interface. Thus developers have no choice but modifying LLVM source tree to overwrite those flags by hard-coded values, which is absolutely a bad practice.

Other cases like turning on advanced mode in some LLVM passes (e.g. the `-basicaa-recphi` flag in BasicAA to recursively analyze PHI nodes) during performance tuning, or using LLVM's built-in bisection features (i.e. `-opt-bisect-limits`) will also be benefit from this proposal. One should expect this new functionality to be:
1. Handy when they're developing or debugging the LLVM part in `ponyc`.
2. Working well with existing `ponyc` command line options.
3. Not available in release build, as we want to keep minimum exposure of internal LLVM part to normal users.

# Detailed design
LLVM already has a nice and handy infrastructure for command line interface. Configuring command line options for LLVM would be as simple as calling just one function (i.e. `llvm::cl::ParseEnvironmentOptions`). The real challenge here is to avoid conflicts between LLVM-specific command line options and existing `ponyc` command line options. Here are two possible options:

## Option1 - Clang style options prepending
For every LLVM-specific command line option, one need to prepend a special token command line options before it. For example, to pass `-basicaa-recphi` , a LLVM-specific option, to `ponyc`, instead of running command like this:
```
ponyc -basicaa-recphi <rest of the ponyc options>
```
We need to prepend a token, says `-mllvm` ,  before `-basicaa-recphi` :
```
ponyc -mllvm -basicaa-recphi <rest of the ponyc options>
```
If there are multiple options, we need to prepend the token on _each_ of them:
```
ponyc -mllvm -basicaa-recphi -mllvm -stats-json <rest of the ponyc options>
```
In addition to boolean flags, if we're using a value flag, where there is a space between the flag name and value, we need to prepend the token on the flag _and_ the value. For example, originally we will use the `-opt-bisect-limits` option like this in LLVM `opt`:
```
opt -opt-bisect-limits 20 <rest of the opt options>
```
In here, we need to use like this:
```
ponyc -mllvm -opt-bisect-limits -mllvm 20 <rest of the ponyc options>
```

## Option2 - Comma separated list
Another approach is to join all the LLVM-specific options into a comma separated string, and pass it to `ponyc`. For example, if we want to pass `-basicaa-recphi` and `-stats-json` to `ponyc`, we do:
```
ponyc -llvm_opts=-basicaa-recphi,-stats-json <rest of the ponyc options>
```
To pass the aforementioned `-opt-bisect-limits 20` option to `ponyc`:
```
ponyc -llvm_opts=-opt-bisect-limits,20 <rest of the ponyc options>
```
However, some of the LLVM options have _already_ been comma separated (e.g. the `-debug-only` option). We can solve this by using different separator, for example, the '+' symbol:
```
ponyc -llvm_opts=-debug-only+dce,licm+-stats-json <rest of the ponyc options>
```

I think pros and cons of these two options are complementary: Option1 is a little bit annoying as we need to prepend a lot of `-mllvm` tokens if our option list is long, but it can avoid the seperator symbol confusion occurs in option2. On the other hand, option2 looks more straight forward and less wordy. However, even we're not using comma as the separator symbol, picking a right separator symbol is still tricky as it might not compatible with future LLVM changes. Therefore, it might be a good idea to include _both_ approaches in `ponyc`.

Another detail is that this feature should only be turned on in dev builds. Since it is probably only useful for `ponyc` developers, and we want to keep minimum exposures of internal LLVM components as well.

# How We Teach This
This idea is best presented as an improvement for `ponyc` development experience. Especially the development of LLVM part in `ponyc`.

This idea will be a new feature for `ponyc`. And we do not need to alter any of the existing Pony guideline rules. Nevertheless, we could add this as a new pattern into `ponyc` developer's guildline as the suggested way to debug the LLVM part.

# How We Test This
This feature should not break the existing tests. But we need new tests for this feature.

The new tests should make sure that LLVM-specific options are correctly forwarded. Thus unit tests are not necessary, the tests could be performed by executing `ponyc` and checking its output message.

The standard CI coverage should be sufficient and there is no manual intervention required.

# Drawbacks
The LLVM interfaces changes pretty fast, thus there is no gurantee on compatibilities of using LLVM-specific command line options.

# Alternatives

Use environment variables to pass LLVM-specific command line options. Similar to what Julia lang does: https://docs.julialang.org/en/v1/manual/environment-variables/index.html#JULIA_LLVM_ARGS-1 .

# Unresolved questions

Should we use both Option1 and Option2 approaches mentioned in the _Detailed design_ section?

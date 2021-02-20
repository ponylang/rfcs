- Feature Name: Force declaration of FFI functions
- Start Date: 2021-02-17
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

This proposal aims to make mandatory the declaration of all C-FFI (Foreign Function Interface) functions through `use` statements, such that the compiler is able to distinguish variadic functions from regular functions. In addition, it also aims to remove from the language the ability to specify the return type of an FFI function at the call site, as this is made redundant in the face of mandatory declarations.

# Motivation

Currently, the Pony compiler treats all undeclared C-FFI functions as variadic, even if the function has a fixed number of arguments (a regular function). This doesn't cause a problem in any of the currently supported platforms, since their calling conventions allow to treat regular functions as variadic, and vice versa.

In the process of adding support for macOS ARM64 (also known as Apple silicon) to the Pony compiler, it was noted that the calling conventions differ for variadic and regular functions: variadic functions expect arguments to be placed on the stack, and regular functions expect all arguments to be placed in registers. If Pony treats regular FFI functions as variadic (or vice versa), the resulting program may crash at runtime. The calling convention distinction is explicitly mentioned in Apple's [developer guide](https://developer.apple.com/documentation/apple_silicon/addressing_architectural_differences_in_your_macos_code#3616882), and is also present on Apple iOS. This is unlike x86 and Linux ARM64, where both kinds of functions share the same calling convention.

In order for the Pony compiler to use the appropriate calling convention, it must be able to distinguish if the target function is variadic or not. This is already possible by declaring the type of a FFI function in advance via `use` statements, with variadic functions denoted with the `...` syntax, as in the [following example](https://github.com/ponylang/ponyc/blob/5adc352daca5666d3e3418bdbbe544ecf62036cb/examples/ifdef/ifdef.pony#L6):

```pony
use @printf[I32](fmt: Pointer[U8] tag, ...)
```

In the absence of an explicit declaration, Pony will assume the function is variadic, which produces incorrect results. If users don't write explicit declarations, they won't be sure that their FFI code works correctly. What's worse, the mistakes caused by Pony treating FFI functions as variadic by default won't be noticeable to users unless they run their programs on platforms with non-compatible calling conventions, since most platforms treat variadic and regular functions in the same way.

Making declarations mandatory only for variadic FFI functions would make it hard for the Pony compiler to detect undeclared variadic C functions, given that it is impossible to distinguish a regular function from a variadic function that is always called with the same number of arguments. This limitation would restrict the ability of the Pony compiler to give meaningful errors to users. Making declarations mandatory only for variadic FFI functions is also confusing for users, as the choice of making some declarations mandatory while others are kept optional can feel arbitrary unless they have explicit knowledge of calling convention differences.

Given that forgetting to write `use` declarations for variadic functions could cause Pony programs to crash at runtime only when run on specific platforms, this proposal aims to make `use` declarations mandatory for _all_ FFI functions, variadic or not. In this way, the Pony compiler will be able to give meaningful error messages when a FFI function is used, but not declared via a `use` statement.

With mandatory declarations in place, specifying the return type for an FFI function at the call site is made redundant, so it should be removed from the language to minimise syntax noise.

# Detailed design

The change proposed in this RFC will remove the possibility of calling a C-FFI function without having previously declared it using `use` statement. Attempting to call a C-FFI function that doesn't have a declaration will result in a compile-time error.

In the Pony compiler, the information as to whether an FFI function is variadic or not comes from several places:

1. For the set of FFI functions that are needed to run a minimal Pony program, this information is hard-coded in the compiler, added when `init_runtime` is called during the code generation pass.

2. From `use` declarations. If the declaration uses the `...` literal as the last parameter of the function, Pony will consider it variadic. Otherwise, the function is considered to have a fixed number of parameters.

3. From FFI calls. If no explicit declaration for a function is provided, the compiler will attempt to generate one based on the first call to such function, and future calls to the same function will be checked against the generated declaration. The compiler generates the declaration as follows:

    - If the function is intrinsic (of the `"@llvm.*"` or `"@internal.*"` form), the compiler will use the exact arguments supplied to the function at the call site to generate a regular function. Currently, all intrinsic functions have a fixed number of parameters, so this doesn't cause any problems.

    - Otherwise, it will consider the function to be variadic, such that any future calls to this function will type-check as long as they have the same return type.

This RFC proposes to remove option (3) above. The default behaviour by the compiler of generating a variadic function if it doesn't have an explicit declaration is only sane if the final program is correct. As explained in the motivation, this is not the case in platforms where variadic functions use a different calling convention from regular ones. It's important to note that this distinction also applies when attempting to call variadic functions as if they were not: the result will also be incorrect.

Since we expect the compiler to catch any possible errors that can arise at runtime, it is expected that the compiler enforces mandatory `use` declarations, at least for variadic functions. However, from the point of view of the compiler, it is impossible to distinguish regular functions from variadic ones that happen to always use the same number of arguments. Merely changing (3) above so that the compiler generates FFI functions as if they had a fixed number of parameters by default, and relying on heuristics to know if a function is variadic, will not work. It is for this reason that this RFC aims to enforce declarations for _all_ FFI functions.

## Removing explicit return type declarations at call sites

Currently, one can specify the return type of an FFI function at the call site, as such:

```pony
let foo = @printf[I32]("some words here".cpointer())
```

If a declaration for an FFI function is not provided, the compiler enforces that an explicit return type is specified, since otherwise it wouldn't have enough information to generate the correct function signature. If the programmer provides an explicit `use` declaration, specifying the return type at the call site is still allowed, with the compiler attempting to type-check the types against the original declaration.

However, if `use` declarations are made mandatory for all FFI calls, the use of the return type at the call site is made redundant. As such, if this RFC is accepted, the option to specify the return type of an FFI call will be removed, and the compiler should treat any explicit return type declarations as a syntax error. Keeping the option of specify return types at the call site could be confusing to the users: specifying the correct return type would not accomplish anything, so it can only become a source of unintentional type-check errors.

## Compiler changes

Changes related to enforcing FFI declarations:

1. In the `expr` pass: the `expr_ffi` function in `ffi.c` should ensure that an explicit declaration exists for all FFI calls. If a declaration is not found, it should emit an error, stopping the compilation process. Intrinsic and internal functions should also require declarations.

2. In the `reach` pass: the `reachable_ffi` function in `reach.c` won't need to defer reification of an FFI call due to having an undeclared FFI declaration.

3. Code generation: the `gen_ffi` function in `gencall.c` won't need to generate FFI declarations on the fly, and as such it can be simplified, since it will always have enough information to generate the correct function for LLVM. Intrinsic and internal functions will no longer be generated as regular functions by default, the compiler will use the provided declarations.

Changes related to removing explicit return types on FFI calls:

1. In the `name` pass: the `ffidecl` rule in `treecheckdef.h` should change to remove the return type.

2. In the `reach` pass: the `reachable_ffi` function in `gencall.c` should remove any references to the return type of the FFI call.

3. Code generation: the `declared_ffi` function in `ffi.c` should change to remove any references to the return type of the FFI call. This function can be simplified to remove any type-checking related to the return type of the function.

## Standard Library, example, test changes

All FFI functions without a corresponding declaration should be updated. Here follows a list of all examples and files in the standard library that should be changed, along with how many lines contain FFI calls in each one.

```shell
> grep -n "@.*\[" -r packages/*/*.pony examples/*/*.pony | grep -v "use @.*" | grep -v "\`@.*" | awk -F':' '{print $1}' | sort | uniq -c
   6 examples/fan-in/main.pony
   4 examples/message-ubench/main.pony
  10 examples/under_pressure/main.pony
   1 packages/assert/assert.pony
   2 packages/builtin/_to_string.pony
   3 packages/builtin/env.pony
  64 packages/builtin/float.pony
  85 packages/builtin/signed.pony
   5 packages/builtin/std_stream.pony
   1 packages/builtin/stdin.pony
   2 packages/builtin/string.pony
  89 packages/builtin/unsigned.pony
   4 packages/builtin_test/_test.pony
   5 packages/builtin_test/_test_valtrace.pony
   1 packages/capsicum/cap.pony
   8 packages/capsicum/cap_rights.pony
   2 packages/collections/_test.pony
   3 packages/collections/hashable.pony
   3 packages/debug/debug.pony
   3 packages/files/_file_des.pony
   2 packages/files/_test.pony
  23 packages/files/directory.pony
   4 packages/files/file.pony
   3 packages/files/file_info.pony
  21 packages/files/file_path.pony
   2 packages/files/path.pony
   2 packages/format/_format_float.pony
   6 packages/net/dns.pony
  11 packages/net/net_address.pony
   2 packages/net/ossocket.pony
   1 packages/net/ossockopt.pony
  17 packages/net/tcp_connection.pony
   9 packages/net/tcp_listener.pony
  17 packages/net/udp_socket.pony
   2 packages/ponybench/_runner.pony
   1 packages/ponytest/pony_test.pony
  16 packages/process/_pipe.pony
  16 packages/process/_process.pony
   9 packages/serialise/serialise.pony
   2 packages/signals/signal_notify.pony
   1 packages/term/ansi_term.pony
   4 packages/time/posix_date.pony
  10 packages/time/time.pony
```

The above command outputs all calls with an explicit return type (which means a declaration is not in scope), excludes declarations and possible calls made in comments. Remove anything past `awk` to see all FFI calls in their context.

## Compiler test changes

All `ponyc` tests that contain FFI calls will need to be updated to use explicit declarations. Here follows a list:

```shell
> grep -n "@.*\[" -r test/*/*.cc | grep -v "use @.*" | awk -F':' '{print $1}' | sort | uniq -c
   4 test/libponyc/badpony.cc
  13 test/libponyc/bare.cc
  37 test/libponyc/codegen.cc
   8 test/libponyc/codegen_ffi.cc
   5 test/libponyc/codegen_final.cc
  17 test/libponyc/codegen_identity.cc
   1 test/libponyc/codegen_optimisation.cc
 102 test/libponyc/codegen_trace.cc
   1 test/libponyc/compiler_serialisation.cc
  10 test/libponyc/ffi.cc
   3 test/libponyc/iftype.cc
   1 test/libponyc/parse_entity.cc
   3 test/libponyc/signature.cc
   5 test/libponyc/verify.cc
```

## Pony libraries under the ponylang org

Downloaded all repos under the ponylang org, ran grep, then removed some false positives:

```shell
> grep -n "@.*\[" -r --include=\*.pony . | grep -v "use @.*" | awk -F':' '{print $1}' | sort | uniq -c
   4 ./appdirs/appdirs/known_folders.pony
   1 ./corral/corral/test/integration/test_info.pony
  33 ./crypto/crypto/digest.pony
  16 ./crypto/crypto/hash_fn.pony
   4 ./net_ssl/net_ssl/_ssl_init.pony
  26 ./net_ssl/net_ssl/ssl.pony
  26 ./net_ssl/net_ssl/ssl_context.pony
  18 ./net_ssl/net_ssl/x509.pony
   1 ./reactive_streams/examples/spl4/main.pony
   9 ./regex/regex/match.pony
  11 ./regex/regex/regex.pony
```

# How We Teach This

- The ["C FFI" chapter of the tutorial](https://tutorial.ponylang.io/c-ffi.html) should be updated to reflect this change.

    In particular, the ["Calling C from Pony" section](https://tutorial.ponylang.io/c-ffi/calling-c.html) should note that a declaration is needed in order to call a FFI function, as well as introduce the `...` syntax for declaring variadic functions. Although we could expect that users that attempt to use the C FFI will be familiar with the concept of variadic functions, it wouldn't hurt to mention them, even if we don't use the "variadic" term.

    The chapter should also remove any explicit type declarations from FFI calls.

- All the examples that show FFI code, be it in the `examples/` folder of the compiler or on the tutorial should be changed to include mandatory declarations, and remove return types at the call site. These examples are located in the C FFI and [Serialisation](https://tutorial.ponylang.io/appendices/serialisation.html) chapters, and in the [examples appendix](https://tutorial.ponylang.io/appendices/examples.html).

In general, the use of the C-FFI should be considered an advanced feature, as its usage can violate many of the safety properties enforced by the language. As such, not much would change for regular Pony users.

# How We Test This

* All currently supported platforms have common calling conventions for regular and variadic functions. The change in code generation shouldn't affect any of these platforms.

* The use of the appropriate calling conventions will be handled by LLVM. We would assume that LLVM is able to do this correctly for all supported platforms.

* Compiler tests can/should be written to demonstrate that programs that lack explicit FFI declarations fail to compile.

* Apple ARM64 should be added as a target platform for CI when our current provider (Cirrus CI) offers instances of this type. In the meantime, the Pony team owns two machines with Apple Silicon chips that should serve as testing infrastructure.

* We should ensure that `use` scoping rules allow us to remove explicit return types on FFI calls.

# Drawbacks

* Breaks existing code that uses FFI functions.

* Imposes overhead on users to declare the type of FFI functions in advance.

# Alternatives

* Make the compiler treat FFI functions as regular functions by default, and require explicit declaration only for variadic FFI functions.

* Use an alternative syntax to let the compiler know about variadic functions at the call site, so that a declaration is not needed, such as (for example) `@printf[I32](...)(arg1, arg2)`.

* Leave the compiler as it is, and do not support platforms with different calling conventions.

# Unresolved questions

Exact implementation details are still to be determined.

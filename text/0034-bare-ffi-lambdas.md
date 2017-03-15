- Feature Name: (bare-ffi-lambdas)
- Start Date: (2017-02-20)
- RFC PR: https://github.com/ponylang/rfcs/pull/79
- Pony Issue: https://github.com/ponylang/ponyc/issues/1690

# Summary

This proposal adds "bare" lambdas, for use in FFI interoperation with C libraries that use function pointers as callbacks.

# Motivation

Many C APIs use function pointers as callbacks, but Pony's FFI features do not currently support them (in the general case), due to Pony consistently using a calling convention that places the receiver object in the first argument. Certain specific cases can be supported when the first argument of the callback function can be correlated to a Pony receiver object, but there are many C APIs where this workaround cannot be made to work, including many APIs that place the most logical receiver object in the final argument position.

This proposal adds "bare" lambdas, which can be used as function pointers in FFI calls, and do not have a receiver object in the first argument slot. As a result, they can accept any argument pattern specified by the C API with which interoperation is desired.

Adding this feature would bring interoperability with a broader subset of useful C libraries.

Some snippets used as code examples in this RFC come from one such C library, `libkyotocabinet`.

# Detailed design

## Usage

A "bare" lambda type is specified using the same syntax as other lambda types, with the small variation that it is prefixed with an `@` symbol.

The only allowed capability for a "bare" lambda object is `val`.

The `@` symbol is already associated in Pony as being an indicator of C-interoperability, including being used as a prefix for FFI calls, and as a prefix for Pony types that are to be exported/exposed when building a C-facing library from Pony source. This new use of the `@` symbol is consistent in spirit with those other two existing uses.

Below is an example of a real-world C `typedef` for a callback type, and an example of what the corresponding Pony `type` declaration might look like:

```c
typedef const char* (*KCVISITFULL)(const char* kbuf, size_t ksiz,
                                   const char* vbuf, size_t vsiz,
                                   size_t* sp, void* opq);
```

```pony
type KCVisitFull[A] is @{(Pointer[U8], USize, Pointer[U8], USize,
                          Pointer[USize], A): Pointer[U8] tag} val
```

Similarly, a "bare" lambda literal would be specified with the same syntax as other lambda literals, with the added `@` prefix.

All of the normal rules of lambda syntax apply, except that:
* specifying lambda captures is disallowed
* using the `this` keyword (explicitly or implicitly) within the lambda body is disallowed
* specifying a receiver capability is disallowed
* the only allowed capability for the resulting "bare" lambda object is `val`

Any breach of these rules will result in a helpful compiler error.

Below is an example that creates a "bare" lambda literal matching the "bare" lambda type from the earlier example:

```pony
type KCScanParallelFn is {(String, String)}

class KCDB
  fun scan_parallel(fn: KCScanParallelFn): Bool =>
    """
    Scan each database record in parallel with a read-only operation.
    """
    let callback: KCVisitFull[KCScanParallelFn] =
      @{(kbuf: Pointer[U8], ksiz: USize, vbuf: Pointer[U8], vsiz: USize,
        sp: Pointer[USize], visitor: KCScanParallelFn): Pointer[U8] tag
      =>
        key   = String.from_cpointer(kbuf, ksiz)
        value = String.from_cpointer(vbuf, vsiz)

        visitor(key, value)

        Pointer[U8] // return NULL pointer - this is a read-only callback
      }

    0 != @kcdbscanpara[I32](this, callback, visitor, 1)
```

"Bare" lambda objects are callable in Pony, just as all other lambda objects are, either by calling the `apply` method of the object, or using the `apply` sugar syntax that appears to invoke the object itself.

However, "bare" lambda objects will not match an `interface` or lambda type designed for a "non-bare" lambda object, or vice versa - their "bareness" sets them apart, as the caller needs to be able to distinguish between "bare" and "non-bare" when invoking because the latter requires the receiver as an extra argument and the former does not.

The actual value of a "bare" lambda object is a C-style function pointer, rather than a full-fledged Pony object. Like Pony `struct`s, a "bare" lambda cannot be used in a type union or as a type argument.

Another style of arriving at "bare" lambda objects is through partial application of a "bare" method - one that uses the `@` signifier as a prefix for the method name. The following snippet demonstrates an synonymous implementation of the earlier example "bare" lambda, but this time implemented as a "bare" method on a `primitive`:

```
type KCScanParallelFn is {(String, String)}

primitive _Visitor
  fun @scan_parallel(kbuf: Pointer[U8], ksiz: USize, vbuf: Pointer[U8],
    vsiz: USize, sp: Pointer[USize], visitor: KCScanParallelFn)
    : Pointer[U8] tag
  =>
    key   = String.from_cpointer(kbuf, ksiz)
    value = String.from_cpointer(vbuf, vsiz)

    visitor(key, value)

    Pointer[U8] // return NULL pointer - this is a read-only callback

class KCDB
  fun scan_parallel(fn: KCScanParallelFn): Bool =>
    """
    Scan each database record in parallel with a read-only operation.
    """
    let callback: KCVisitFull[KCScanParallelFn] =
      @{(kbuf: Pointer[U8], ksiz: USize, vbuf: Pointer[U8], vsiz: USize,
        sp: Pointer[USize], visitor: KCScanParallelFn): Pointer[U8] tag
      =>
        key   = String.from_cpointer(kbuf, ksiz)
        value = String.from_cpointer(vbuf, vsiz)

        visitor(key, value)

        Pointer[U8] // return NULL pointer - this is a read-only callback
      }

    0 != @kcdbscanpara[I32](this, _Visitor~scan_parallel(), visitor, 1)
```

Because "bare" methods have no receiver, they may not access any fields, and may not reference the `this` identifier in their body.

The partial application of a "bare" method yields an object that is functionally identical to a "bare" lambda, and corresponds to a C function pointer in FFI invocations.

## Implementation

Each "bare" lambda literal will be sugared to an anonymous primitive containing a single `apply` method, just as with other lambdas that do not have any captures.

However, the apply method will be tagged with some manner of special flag that is known to the type system and code generator, distinguishing it as "bare". Specificaly, `TK_AT` will be the receiver capability, just as it is when using the "bare" method syntax, where `@` takes the place of the receiver cap keyword.

When determining subtyping relationships, the compiler must consider a "bare" lambda literal to only be a subtype of "bare" lambda types, using the aforementioned special flag.

When code-generating the call site of a Pony call to a "bare" lambda object, the compiler must take into account the "bare" or "non-bare" status of the called function, to determine whether the receiver argument should be omitted or passed in the first slot as normal, and whether to use the receiver itself as a C-style function pointer.

When code-generating the function implementation, the compiler must take into account the "bare" or "non-bare" status of the called function, to determine whether the receiver parameter should be omitted or received in the first slot as normal.

When code-generating partial-application, the compiler must take into account the "bare" or "non-bare" status of the called method, to determine whether it's value should be a C-style function pointer, or a normal Pony callable object.

The compiler must enforce the restrictions mentioned in the *Usage* section above, including helpful compiler error messages for all restricted cases.

# How We Teach This

Bare lambdas should be mentioned and explained in the FFI section of the tutorial, since they are intended to be used with and only useful in the context of FFI.

Bare lambdas should be demonstrated and compiled in an example in the `examples` subdirectory of the `ponyc` repo, similar to the `ffi-struct` example.

# How We Test This

Compiler tests can/should be written to demonstrate all restricted cases.

Compiler tests can/should be written to demonstrate proper code generation.

The aforementioned example in the `examples` subdirectory of the `ponyc` repo can be compiled and run to demonstrate correct operation of the lambdas.

# Drawbacks

* Adds another (arguably consistent and reasonable) use of the `@` symbol.

* Adds additional logic in the compiler to account for handling the "bare" semantics, as mentioned in the *Implementation* section.

# Alternatives

* Leave the system as it currently is, and do not support creating C callback functions. When users ask about interoperating with C libraries that use callbacks, continue to suggest compiling a shim of C code alongside the pony program/package.

* Don't include "bare" methods, and only allow "bare" lambda objects. This was the original scope of the RFC, but it was expanded after some discussion in a sync call.

* Allow accessing "bare" method values as if they were field reads, instead of requiring partial application syntax. This was also discussed in the sync call, but I've chosen to leave it out here as I believe it requires too much extra "benefits" and special casing for a language feature that will only seldom be used (only with a fraction of FFI libraries is it necessary).

# Unresolved questions

Exact implementation details are still to be determined.

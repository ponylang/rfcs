- Feature Name: modulo_operator
- Start Date: 2018-11-09
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Add a modulo operator `%%` for integer and floating point types that is defined as the remainder after floor division. Most importantly the result always has the sign of the Divisor, in contrast to `rem` (`%` operator), whose results always have the result of the dividend.
This RFC will also add floored division as a method on integer and floating point types.

# Motivation

Before Pony Release 0.25.0 the `%` operator on integer types, called `mod` at that time, was actually calculating the remainder after division truncating towards zero
and the result always had the sign of the dividend. Most other languages also implement this operation, as it has nice hardware support (e.g. DIV/IDIV instruction on x86)
but they call it `rem`. [Reference](https://en.wikipedia.org/wiki/Modulo_operation#Remainder_calculation_for_the_modulo_operation)  Amongst those languages are Ada, Julia, Haskell, Clojure, MATLAB, Prolog and more.
In order to achieve consistency here, the `%` operator has been renamed to `rem`. This RFC aims at creating the missing `mod` operator whose result always has the sign of the divisor, that also exists in may other languages.

## Language Examples

### Julia

**rem**

- Defined as the remainder from euclidian division (truncating towards zero).
- The result has the sign of the dividend.
- For integers implemented by LLVM [`srem`](https://releases.llvm.org/6.0.1/docs/LangRef.html#srem-instruction)/[`urem`](https://releases.llvm.org/6.0.1/docs/LangRef.html#urem-instruction) instruction.

**mod**

- For Integers it is defined as remainder from floored division.
- For floats, no flooring is involved, it just uses the sign of the divisor, but the actual remainder operation is the same.
- The result has the sign of the divisor.
- [Integer Implementation](https://github.com/JuliaLang/julia/blob/0d713926f85dfa3e4e0962215b909b8e47e94f48/base/int.jl#L182-L225)
- [Float Implementation](https://github.com/JuliaLang/julia/blob/7ea4542359b8629621a1f3cdb1f9aa97fdcfcde2/base/float.jl#L424-L433)


### Haskell

**rem**

- Defined as remainder after the `quot` operation, which is division truncating towards zero.
- The result has sign of the dividend.
- Satisfies the following rule: `(x quot y) * y + (x rem y) == x`
- Multiple implementations are possible, when using llvm, it uses [`srem`](https://releases.llvm.org/6.0.1/docs/LangRef.html#srem-instruction)/[`urem`](https://releases.llvm.org/6.0.1/docs/LangRef.html#urem-instruction)/frem for floats.

**mod**

- For integers defined as remainder after `div`, which is floored division, rounded towards negative infinity.
- The result has the sign of the divisor.
- Satisfies the following rule: `(x div y) * y + (x mod y) == x`.

As in those languages, Pony should also get back its `mod` operator/function, but this time, correctly defined as the remainder after *floored division* (for integers) which truncates the result towards negative infinity. For floats `mod` should not be truncating, but always have the sign of the divisor.

# Detailed design

The `mod` function will be defined on all integer and floating point types and will have an accompagnying operator: `%%`.

## Integers

For Integer types this operator will have the partial and unsafe variants: `%%?` and `%%~`. There will also be a `modc` function being added, returning a flag for overflow/underflow and the actual result.

`mod` will be defined as the remainder from floored division (rounded towards negative inifinity).

As the current integer division operation is truncated towards zero, an additional floored division function needs to be defined on all integer types. This one will be called `fld`. This function will have no operator symbol mapping to it. For unsigned integer types, floored division will be the same as `div`. For signed integer types it needs to be implemented differently. To stay consistent there will also be `fld_unsafe`, `fld_partial` and `fldc`.

Floored division for signed integers will be implemented as follows:

```pony
// this example uses I64, but can be generalized to any signed integer type
  fun fld(y: I64): I64 =>
    let div_res = this / y
    if ((this xor y) < 0) and (div_res * y != this)) then
      div_res - 1
    else
      div_res
    end
    
```

With floored division being defined, `mod` can be implemented as:

```pony
// this example uses I64, but can be generalized to any signed integer type
// and assumes floored division being implemented as fld
  fun mod(y: I64): I64 =>
    this - (fld(this, y) * y)
```

Floored division and `mod` will satisfy the following rule: `((fld(x, y) * y) + mod(x, y)) == x`

## Floating Points

The floating point `fld` will be implemented as `(x / y).floor()`.

The floating point `mod` will apply the `rem` operator and make sure the result has the sign of the divisor.

# How We Teach This

The new operators will be added to the operator list in the tutorial. The differences between `rem` and `mod` and between `div` and floored division
will be also explained in the respective docstrings.

# How We Test This

Add test cases to stdlib tests that ensure that mod and floored division work according to their definition on all integer and floating point types.
Verify that `((fld(x, y) * y) + mod(x, y)) == x` holds. Also verify that the same equation is true for the pair of `rem` and `div`.

# Drawbacks

* Maintenance cost of added code, as we get an additional operator

# Alternatives

It is also possible to implement both of these functions in the `math` package in stdlib instead of definining it for the integer and floating point types in the `builtin` package.

It is also possible to just leave the integer and floating point types as they are. e.g. Rust also only seems to supply the `rem` operation.

Maybe a more efficient solution exists, which i am not aware of right now. This might also depend on the CPU instruction set.

# Unresolved questions

None.

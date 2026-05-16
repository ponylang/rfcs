- Feature Name: `\do_not_use\` annotation
- Start Date: 2026-04-03
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Make the compiler emit a "Do not use!" warning when compiling code with the `\do_not_use\` annotation.

# Motivation

Sometimes, implementing a trait or interface can only be done partially: some methods don't make sense. For example, in an infinite-precision integer class that implement `SignedInteger` trait, the methods `min_value` and `max_value` have no sense: there is no minimal or maximal values possible, because the trait contract applies only to fixed-width integers. But the `SignedInteger` trait features cover 95% of the infinite-precision implementation, and it isn't worth adding a new type like `SignedInfiniteInteger` to cover these cases. Reusing an existing type makes the class more useful to client programmers that can substitute it to existing types with limited changes in their code.

# Detailed design

When the Pony compiler encounters a `\do_not_use\` annotation in the code, it emits a "Do not use" warning message at compilation time with information (source file, line number, method or other [contexts](https://tutorial.ponylang.io/appendices/annotations#what-can-be-annotated) where annotations can be used) where this information has been encountered. The programmer can see that her code uses features that must not be used because results are impredictable.

Similarly, the compiler or pony-doc must injects the warning message into the documentation of the feature. The text of the message in the documentation must warn the reader not to use the feature, perhaps with an icon or a visual hint like found in othe languages documentation (Random example from https://doc.rust-lang.org/stable/std/primitive.u128.html#method.bit_width).

## Where can it be used?

Usually this annotation only makes sense when applied to global symbols like:

* `actor`
* `class`
* `struct`
* `primitive`
* `trait`
* `interface`
* `new`
* `fun`
* `be`

But it must also be accepted in other contexts like `if` or `match` because it can occur in platform-dependant code (i.e. within `ifdef` blocks). 

## Example

To continue with the infinite-precision integer example and the `SignedInteger` trait. Here are methods that must be annotated with `\do_not_use\`:

* `min_value`: There is no minimal value in an infinite integer, as we can't represent -∞ with `SignedInteger` trait.
* `max_value`: Similarly, there is no maximal value and +∞ can't be represented as we can always create a new value greater than any existing instance.
* `clz`: No way to count the number of leading `0` bits. Only valid for fixed-size integer representations.
* `clz_unsafe`: Idem.
* `rotl` and `rotr`: Rotating bits can't happen if the width of the integer representation is not fixed.
* `bit_reverse` and `bswap`: These methods could be implemented with an infinite-precision integer representation, but their meaning is not clear and results probably would surprise the user. 

The remaining >100 methods of `SignedInteger` have a valid implementation in this variable-width integer class. More than 95% of the trait featurures have sense while a few methods produce results that can surprise the programmer who uses them.

# How We Teach This

This new compiler annotation will be added to the [list of recognized annotations](https://tutorial.ponylang.io/appendices/annotations#annotations-in-the-pony-compiler) with explanations on what to do when encountered.

It can be mentioned in the tutorial, in a place discussing compiler error messages (to be written?). It is not mandatory as it is an advanced feature, but useful for completeness of the documentation. 

# How We Test This

Tests of the `\do_not_use\` annotations are similar to those of the other annotations. Minimally, we must test that a warning message is output during the compilation when the annotation is present in the source.

# Drawbacks

Not implementing such feature, a client programmer could use API that is not *reliable* and get surprising/not-expected results. In absence of such annotation, client can create bugs when they use these API. This annotation is used to prevent programmers from using these API inadvertently.

# Alternatives

## Poor man alternative

Annotations are implementation-specific hints to the compiler. One can run `grep` in the `Makefile` and print the warnings if this annotation is found in the source files. The problem with such solution is that you get the warning message as soon as you compile a source where the `\do_not_use\` annotation is present, even if you don't use a forbidden method. In our infinite-precision integer example, as soon as a programmer uses this class, the warning is always issued. Vague warnings are not useful.

## Change types ontology

Taking again the example of the infinite-precision integer, one can change the types structure. Like we've seen, the variable-size integer can't implement some methods of the `SignedInteger` trait. We can define new traits like `VariableWidthInteger` and `FixedWidthInteger` and change the type dependencies.

```pony
trait VariableWidthInteger is (FixedWidthIntger & BitOperable)
    ...

type SignedInteger is (FixedWidthInteger | VariableWidthInteger)
```

Building a correct types ontology is not easy. This would render the base types of the stdlib more complex to users. Additional complexity is not a good thing.

# Unresolved questions

As presented, this is a compilation-time only message. But should we have the compiler emit code when encountering the annotation to output the warning message at run-time when compiled in debug mode? This would be realy nice as the client programmer is warned even when she uses a pre-compiled library and she hasn't read the documentation. That is really a safe-guard!

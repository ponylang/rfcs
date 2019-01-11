- Feature Name: Remove Traits from Pony
- Start Date: 2019-01-11
- RFC PR: 
- Pony Issue: 

# Summary

Remove traits from Pony, leaving only interfaces.

# Motivation

As it currently stands with Pony. Traits and Interfaces are almost identical.  There's nothing you can do with one that you can't do with the other.

New users coming to Pony often end up in Pony support channels asking what the difference between the two are. We generally explain that traits are nominal subtyping and interfaces are structural subtyping and this is mostly true except, that you use the `is` keyword when implementing an interface to get compile time checks to make sure you are implementing said interface.

All in all, its rather confusing. 

Where possible, we should be aiming to provide the minimum number of concepts in Pony to allow a user to solve the problem they have at hand. There is no problem that traits solves that can not be solved with interfaces. There are however things you can do with structual subtyping and interfaces that you can't do with traits.

Interfaces provide structural subtyping that allows the user to describe "likeness" of classes after the fact. I can for example, create an interface that describes both a new class I have created as well as classes that are in the standard library. Traits because they are nominally typed do not allow the user to do this.

To quote the tutorial: "traits are a powerful tool as well: they stop accidental subtyping". In theory, this is true. Traits can be used to stop accidental subtyping. In practice, accidental subtyping in Pony is incredibly uncommon. I've yet to experience it in the wild after writing Pony for several years.

To accidentally subtype something using an interface you need to:

- Manage to create a class that shares the same interface as another
- "Accidentally" pass that class to a method that calls for said interface without intending to

The more methods an interface implements, the less like this is to happen accidentally. The most likely case for this to happen would be an interface with no methods. However, such an interface has no value. There is a small amount of value in a trait with no methods.

Using a trait with no methods, you can create enumerations in Pony. For example:

```pony
trait val Color

primitive Red is Color
primitive Blue is Color
primitive Green is Color
```

In the above example, we have created an enumeration with three types of colors. These could then be used elsewhere with pattern matching to "do the correct thing" for a given color.

```pony
primitive ColorHelper
  fun color_to_string(c: Color): String =>
    match c
    | let x: Red => "red"
    | let x: Blue => "blue"
    | let x: Green => "green"
    else "unknown color"
    end
```

Using traits in this fashion leads us directly into [the expression problem](https://en.wikipedia.org/wiki/Expression_problem). To add a new value to the enumeration means we need to find every match for `Color` and update it to include the new value (unless we are happy with getting a default value).

By removing traits from the language, Pony would no longer be able to represent these "open enumeration" types. There is certainly value in them, however, the current means of backing into them using traits is anemic. If we desire having open enumerations in Pony, they should be added as a first class feature.

Removal of traits won't impact on the ability to do the more traditional "closed enumeration" as that is supported in a first class fashion as we can see in the example below:

```pony
primitive Red
primitive Blue
primitive Green

type Color is (Red | Blue | Green)

primitive ColorHelper
  fun color_to_string(c: Color): String =>
    match c
    | let x: Red => "red"
    | let x: Blue => "blue"
    | let x: Green => "green"
    end
```

It is my belief that traits should be removed from Pony due to the above problems. Preventing "accidental subtyping" and allowing "open enumerations" are the only reasons to keep traits as is. I believe that those small advantages are outweighed by:

- Additional complexity when learning of needing to understand the nuanced differences of when to use structural vs nominal typing
- Additional compiler complexity of supporting both interfaces and traits
- Additional possibility for bugs that comes from the additional code to support both

# Detailed design

This is really a removal checklist:

- Update the standard library to use `interface` instead of `trait`. Current usages are in:

* builtin/_partial_arithmetic.pony
* builtin/real.pony
* builtin_test/_test.pony
* cli/command_spec.pony
* files/_test.pony
* format/format_spec.pony
* format/prefix_spec.pony
* logger/_test.pony
* ponybench/_runner.pony
* ponybench/benchmark.pony
* ponytest/_group.pony
* ponytest/test_list.pony
* ponytest/unit_test.pony
* random/random.pony

Additionally, we need to update tutorial, website, and patterns sites to use interface instead of trait.

We should also review all open issue

# How We Teach This

For users familiar with Pony, we are "teaching" the removal:

Note the change in release notes.

For users who come to Pony after this change, we don't have anything to teach. There is one less concept for them to learn. They will only have to learn about interfaces.

However, the [existing tutorial documentation](https://tutorial.ponylang.io/types/traits-and-interfaces.html) should be expanded as interfaces are mostly an afterthought to traits. For example, the usage of `is` is only discussed in relation to traits despite the same functionality being available for interfaces as well.

# How We Test This

Verify that all existing pony and standard library tests continue to pass after the change.

# Drawbacks

This will break existing user code.

# Alternatives

Leave traits in the language.

# Unresolved questions

None that I am aware of.

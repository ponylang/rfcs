- Feature Name: Constrained Types
- Start Date: 2024-01-22
- RFC PR:
- Pony Issue:

# Summary

Add library to the standard library to make it easy to express types that are constrained versions of other types.

# Motivation

We often want to take a basic type and apply constraints to it. For example, we want to represent a range of values from 0 to 9 as being valid and disallow others.

A common approach to doing this is to create a class that wraps our type and only allows the class to be created if the constraints are met. I believe it would be nice to include a way to participate in this common pattern in the standard library.

By providing an approved mechanism in the standard library, we can demonstrate to Pony users how to encode our constrained types within the type system.

# Detailed design

The entire standard library addition can be included in a single file in a new package.

```pony
type ValidationResult is (Validated | Error)

primitive Validated

class val Error
  let _errors: Array[String val] = _errors.create()

  new create(e: (String val | None) = None) =>
    match e
    | let s: String val => _errors.push(s)
    end

  fun ref apply(e: String val) =>
    _errors.push(e)

  fun ref errors(): this->Array[String val] =>
    _errors

interface val Validator[T]
  new val create()
  fun apply(i: T): ValidationResult

class val Valid[T: Any val, F: Validator[T]]
  let _value: T val

  new val _create(value: T val) =>
    _value = value

  fun val apply(): T val =>
    _value

primitive ValidConstructor[T: Any val, F: Validator[T] val]
  fun apply(value: T): (Valid[T, F] | Error) =>
    match F(value)
    | Validated => Valid[T, F]._create(value)
    | let e: Error => e
    end
```

The library could be used thusly:

```pony
type LessThan10 is Valid[U64, LessThan10Validator]
type MakeLessThan10 is ValidConstructor[U64, LessThan10Validator]

primitive LessThan10Validator is Validator[U64]
  fun apply(i: U64): ValidationResult =>
    recover val
      if i < 10 then
        Validated
      else
        let s: String val = i.string() + " isn't less than 10"
        Error(s)
    end
  end

actor Main
  new create(env: Env) =>
    let prints = MakeLessThan10(U64(10))
    match prints
    | let p: LessThan10 => Foo(env.out, p).go()
    | let e: Error =>
      for s in e.errors().values() do
        env.err.print(s)
      end
    end

actor Foo
  let out: OutStream
  var left: U64

  new create(out': OutStream, prints: LessThan10) =>
    out = out'
    left = prints()

  be go() =>
    if left > 0 then
      out.print(left.string())
      left = left - 1
      go()
    end
```

In our example usage code, we are creating a constrained type `LessThan10` that enforces that the value is between 0 and 9.

Some key points from the design:

## We can only validate immutable objects

Validating a mutable item is pointless as it could change and go outside of our constraints after it has been validated. All validated items must be immutable.

## `Error` is immutable

We don't want to allow error mesages to be changed after validation is done. Because everything being validated is sendable, we can wrap an entire validator in a `recover` block and build up error messages on a `ref` Error before lifting to `val`.

## Validators are not composable

There's no safe way with the Pony type system that I can see to make a `Validator` composable. You can say for example that `SmallRange` is `GreaterThan5 & LessThan10` and then use a `SmallRange` where one a `LessThan10` is called for.

# How We Teach This

There's a few areas of teaching. One, the package documentation should have a couple of "here's how to use" examples with explanation as well as an explanation of why you would want to use the package instead of say checking a `U64` repeatedly for being `< 10`.

Additionally, each "class" in the package should have documentation as well as each method.

Finally, I think it makes sense to add a Pony Pattern that highlights constrained types (under a domain modeling section) and points to usage of this new package.

# How We Test This

There's not a lot here to test. I think it is reasonable to construct a few scenarios like "LessThan10", "ASCIILettersString", and "SmallString" that create a few different constraints and verify that we can't break those constraints.

It would be difficult for someone to accidentally break the relatively simple library. A few unit-tests of functionality as detailed above should be fine.

# Drawbacks

Adding this to the standard library means that if we decide we want to change it, it will take longer to iterate vs having this as a ponylang organization library.

# Alternatives

## Where this lives:

Make this a ponylang organization library. I personally want this functionality and will create the library and maintain under the organization if we decided to not include in the standard library.

## `Error` collection type

I think that `Array[String val]` is a good error representation that is easy to work with and gives people enough of what they would need without taking on a lot of generics fiddling that might make the library harder to use. That said, we could look at making Error generic over the the error representation and use something like `Array[A]`.

Additionally, if we thought it would be useful to get back a collection of errors that can be updated by calling code without changing the collection within the `Error` type, we could use a persistent collection type like `persistent/Vec`. Using a persistent collection would allow for additional errors to be "added on" later while the collection in `Error` would itself remain unchanged.

## Names

I'm generally happy with the names, but I would entertain that `Validated` instead of `Valid` reads better. So:

```pony
type LessThan10 is Validated[U64, LessThan10Validator]
```

instead of:

```pony
type LessThan10 is Valid[U64, LessThan10Validator]
```

If we made that change then `ValidConstructor` should become `ValidatedConstructor`.

# Unresolved questions

The package needs a name. I'm thinking `constrained_types` or `constrained`.

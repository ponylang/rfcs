- Feature Name: variance-and-implicit-interfaces
- Start Date: 2018-04-19
- RFC PR:
- Pony Issue:

# Summary

Provide sugar for structural typing (implicit interfaces) by allowing use sites of generic types to notate a type argument as covariant or contravariant, or omit it entirely.

# Motivation

Generic types are very useful, but they can also be cumbersome to use at times.

Any time you wish to reference a generic type, you must also specify the type arguments, because all type parameters must be reified with type arguments during compilation, fully resolving the implementation of the type before code generation. However, there are times when you want to have a reference that can hold any possible reification of that generic type, or some specific subset of the set of all possible reifications.

This goal can be accomplished with structural typing (interfaces), but writing the interfaces by hand creates needless repetition in the code, where every relevant method must have its signature declared again. This takes unnecessary time and effort, slows down the speed of authoring and refactoring code, and introduces more code to review, troubleshoot, and maintain.

Ultimately, this is exactly the kind of non-creative task that the compiler would be much better at than humans are. As long as it's given the appropriate information, the compiler can automatically generate an implicit interface that contains all of the correct method signatures, based on how you invoked it at the use site.

# Detailed Design

This new feature would introduce three new ways of specifying a conceptual set of types as a type argument, resulting in an overall type that is an interface representing some subset of the methods of the generic type:

- `C[+T]` - the subset of methods of `C` where the type argument `T` is used in a covariant position (for example, in the return type), or not at all.

- `C[-T]` - the subset of methods of `C` where the type argument `T` is used in a contravariant position (for example, in an argument type), or not at all.

- `C[_]` - the subset of methods of `C` where the omitted type argument is not used at all.

To demonstrate these concepts, consider the following real-world example, taken from the `pony-resp` library, in which an `Elements` class provides a small wrapper for the `Array` class, meant to act as a read-only representation of nested lists of data received "over the wire":

```pony
type Data is (None | OK | Error | String | I64 | ElementsAny)

primitive OK
  fun string(): String => "OK"

class val Error
  let message: String
  new val create(message': String) => message = message'
  fun string(): String => "Error(" + message + ")"

interface val ElementsAny
  fun string(): String
  fun size(): USize
  fun apply(i: USize): Data?
  fun values(): Iterator[Data]

class val Elements[A: Data = Data] is ElementsAny
  embed array: Array[A] = array.create()
  fun ref push(elem: A) => array.push(elem)
  fun size(): USize => array.size()
  fun apply(i: USize): A? => array(i)?
  fun values(): Iterator[A] => array.values()
  fun string(): String =>
    let buf = recover String end
    buf.push('[')
    for (idx, elem) in array.pairs() do
      if idx > 0 then buf.>push(';').push(' ') end
      buf.append(elem.string())
    end
    buf.push(']')
    buf
```

Note the `ElementsAny` interface that was defined here, and note that it is in the type union of `Data` (because `Elements` instances can be nested). Because this is a data structure that is only meant for reading after it has been filled, `ElementsAny` is defined using the subset of methods of `Elements` where the type parameter `A` (reified here as `Data`) is used in covariant positions (in return types).

With the new syntax, this could have been defined more simply as:

```pony
type ElementsAny is Elements[+Data]
```

This simple type alias would be equivalent to the interface:

```pony
interface val ElementsAny
  fun string(): String
  fun size(): USize
  fun apply(i: USize): Data?
  fun values(): Iterator[Data]
```

If the use site had instead used the contravariant syntax (`Elements[-Data]`), a different set of methods would be included in the interface:

```pony
interface val ElementsAny
  fun string(): String
  fun size(): USize
  fun ref push(elem: Data)
```

Or, if the type argument had been omitted (`Elements[_]`), only the methods not using the `A` type parameter at all would remain:

```pony
interface val ElementsAny
  fun string(): String
  fun size(): USize
```

You might guess that the type argument omission syntax may not be very useful in the real world, because it prevents you from using any methods where the type parameter is in the method signature. However, in the seven examples of this `XAny` pattern that I studied from the body of my own libraries, six of them would be satisfied using the type argument omission interface instead of covariant or contravariant interfaces. These are often cases where the type parameter is used to parameterize some implementation detail of the generic type, but the generic type still implements a set of useful methods where the type parameter doesn't come into play as part of the signature (that is, the signatures are identical in the general case).

# How We Teach This

The tutorial chapter on generics would need a new page to explain these concepts and give some practical examples of use.

# How We Test This

Add compiler sugar tests that verify the anonymous interface that was invoked into existence at the use site gets the proper set of methods in every case.

# Drawbacks

* Adds a new concept and new syntax to represent it in the language. However, I think the burden of learning new syntax is lessened by the following:
    * The `+`/`-` syntax to represent covariance and contravariance is fairly similar to its use in other languages, like Scala
    * The `_` syntax for omission should be quite intuitive, given that it's used in pattern matching and some other places as the "don't care" symbol. In this position it means "Give me the interface for when I don't care what the type argument was".

* Adds some new complexity into the compiler to implement and maintain in the type system.

# Alternatives

- Create the anonymous interface as a trait instead, so that other types not mentioned at the use site won't end up as "accidentally" implementing the anonymous interace.

- Move covariance and contravariance to be part of the type definition (as Scala does) instead of being part of the use site. This has generally been considered an unpopular option in previous discussions, due to the fact that it can be very cumbersome to use correctly, and often there is no single right answer for co/contra-variance to use in the definition of a type - many common generic types include type parameter uses in both covariant and contravariant positions.

- Don't do this at all, leaving the user to always create explicit interfaces when they need them in their code, even when they are highly tedious and/or repetetive with respect to the class or other type they are referencing.

# Unresolved questions

- None.

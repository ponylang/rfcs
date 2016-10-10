- Feature Name: custom_serialization
- Start Date: 2016-10-07
- RFC PR:
- Pony Issue:

# Summary

This feature would allow the programmer to specify custom serialization/deserialization that would be run as part of Pony's built-in serialization/deserializaton process. The custom methods would run after the built-in serialization and deserialization, and would allow the programmer to:
* specify the number of bytes to use for serialization
* write bytes to the serialization buffer
* read bytes from the serialization buffer

# Motivation

This is primarily intended as a way to allow programmers to provide systems for serializing and deserializing objects that contain `Pointer` fields. Currently the runtime will raise an error if an object that contains a `Pointer` field is serialized. For example, consider a situation where a Pony program has logic that is implemented in C and has objects that store pointers to data that is used by C code. It is currently impossible to call `Serialise.apply(...)` on the objects to create serialized representations of them. This becomes an especially pressing issue when attempting to write API code for handling user-created objects that may or may not contain `Pointer` fields, depending on the implementation choices made by the user.

# Detailed design

A class providing its own serialization system would need to implement methods for serializing and deserializing data, as well as a method for conveying the number of additional bytes needed for custom serialization of the object. The runtime would call these methods at the appropriate time to generate serialized data and deserialize that data. Pony's built-in serialization would still be performed on the objects, this system is intended to allow *additional* data to be stored in the serialized representation of the object and recovered by deserialization.

## What Gets Serialized And Deserialized

The intent of this system is to allow the programmer to specify a way to use Pony's existing serialization system to work with objects that contain `Pointer` fields to C data structures. Consequently the expectation is that the system would only be used to serialize and deserialize `Pointer` fields, since the other fields are already serialized by Pony's built-in system. However, there is nothing preventing the user from including information from other fields in the serialized representation, nor from using the serialized data to modify non-`Pointer` fields during deserialization.

## Methods

All of the following methods must be implemented for custom serialization:
* `fun _serialise_space(): USize` -- returns the number of bytes to reserve for custom serialization
* `fun _serialise(bytes: Pointer[U8] tag)` -- takes in a pointer to the location in the serialization buffer that has been reserved for this object's extra data, writes a serialized representation of its data to the buffer
* `fun _deserialise(bytes: Pointer[U8] tag)` -- takes in a pointer to the location in the deserialization buffer that represents the object's extra data, reads the data out, and modifies the object using that data

## Behavior Changes

Currently the runtime raises an error if the program attempts to serialize an object that has a `Pointer` field. This would need to be changed to allow these objects to be serialized.

## Serialization Format

Currently the serialization format represents an object in a byte array like this:

```
address : [ word 1] [ word 2] [ word 3] [ word 4] ... [ word X] [   X+1 ] [   X+2 ]
value   : [type id] [field 1] [field 2] [field 3] ... [type id] [field 1] [field 2]
          [------------------- object 1 --------] ... [-------- object 2 ---------]
```

The `type id` is the index of the object's type in the class descriptor table. Each field is either
1. A raw value that represents a type such as an integer or floating point number
2. A number that represents the index of in the serialized representation in the byte array of the object in this field

(Strings and arrays are handled in a similar but distinct manner, but we can avoid that discussion for now.)

Assume we have code like this:

```
class Foo:
  let _a: Bar
  let _b: U64 = 14
  let _c: U64 = 19

class Bar
  let _f1: U64 = 24
  let _f2: U64 = 27

// ...
  let x = Foo
  let sx = Serialise(x, auth)
```

then the serialized form stored by `sx` might look like this (assuming 8-byte words):

```
address: [  0x00 ] [  0x08 ] [  0x10 ] [  0x18 ] [  0x20 ] [  0x28 ] [  0x30 ]
value:   [   135 ] [  0x20 ] [    14 ] [    19 ] [    95 ] [    24 ] [    27 ]
         [----------- Foo instance ------------] [-------- Bar instance -----]
```

In this case, the `Foo` class has a `type id` of `135` (address `0x00`), the first field of that object (address `0x08`) points to the object that will be deserialized from position `0x20`, the `Bar` class has a `type id` of `95` (address `0x20`), and the rest of the fields are filled with representations of their numeric values.

### Change To The Serialization Format

A class that provides custom serialization will provide a method called `_serialise_space()` that returns the number of bytes that must be added to the end of the object's representation for additional serialization data. The `_serialise_space()` function could always return the same value if all objects of the class are serialized to the same number of bytes, or it could calculate a value based on the serialization format and the size of the object being serialized. The details are entirely up to the implementer. The extra serialization data will appear after the object's fields and before the next object in the byte array.

Changing the last example slightly, assume we have code like this:

```
class Foo:
  let _a: Bar
  let _b: U64 = 14
  var _c: Pointer[U8] = Pointer[U8]
  fun _serialise_space(): USize => 8
  fun _serialise(bytes: Pointer[U8]) => // write 0xBEEF
  fun _deserialise(bytes: Pointer[U8]) => // ...

class Bar
  let _f1: U64 = 24
  let _f2: U64 = 27

// ...
  let x = Foo
  let sx = Serialise(x, auth)
```

then the serialized form stored by `sx` might look like this (assuming 8-byte words):

```
address: [  0x00 ] [  0x08 ] [  0x10 ] [  0x18 ] [  0x20 ] [  0x28 ] [  0x30 ] [  0x38 ]
value:   [   135 ] [  0x28 ] [    14 ] [    19 ] [ 0xBEEF] [    95 ] [    24 ] [    27 ]
         [----------- Foo instance ----------------------] [-------- Bar instance -----]
```

Addresses `0x20` through `0x27` contain the extra data generated by the custom serializer. The deserializer is responsible for converting the serialized representation into a deserialized object and assigning that object to the correct field.

# How We Teach This

This should be taught as part of the C FFI documentation in the tutorial because it is intended to be used by objects that already interact with the C FFI in some way. There should also be a Pony pattern that addresses how to serialize and deserialize objects that have `Pointer` fields.

This is an advanced feature, so it would not change the way that Pony is taught to new users.

An email to the user mailing list and inclusion in the tutorial should be sufficient for letting existing users know about the feature.

# How We Test This

This should be tested in a way that is similar to how the existing C FFI unit tests work. The appropriate Pony class functions should be provided, which in turn call C functions that do the necessary work. An object will be created, serialized, and deserialized, and then the two objects will be compared for equality. This will require another C function to compare the structures that are pointed to.

# Drawbacks

This implementation involves working with pointers and assumes the use of the C FFI, so it could encourage the use of unsafe code, which would undermine one of the main features of Pony. It places most of the burden of doing the right thing on the programmer.

The plan allows the runtime to serialize obects with pointer fields. If the user does not provide the appropriate serialization methods then the deserialized object will contain a null pointer which will most likely cause the program to crash if the program attempts to access that field.

There is an added runtime cost associated with checking for the existence of serialization functions.

# Alternatives

A programmer can create a serialization system of their own if they wish to do so. It will not be usable with by code that relies on the built-in serialization system, so the program would need to differentiate between classes that use the built-in mechanism and ones that provide their own serilization.

# Unresolved questions

There is still a question of which calls should be compiled in to the program vs which should be done at run time. Because of the way that serialization is implemented, it may be easier to determine whether or not a type provides deserialization functions at run time than to conditionally include them at compile time. From my initial investigation, it appears that the call to `_serialise` can added at compile time, but the calls to `_serialize_space(...)` and `_deserialise(...)` would be easier to make a run time. There are probably ways to do everything at compile time, but I believe this would make the code more difficult to reason about. Having said that, the serialization system is already complex in several ways, so perhaps adding a marginal amount of extra complexity would be worth the marginal performance improvement.

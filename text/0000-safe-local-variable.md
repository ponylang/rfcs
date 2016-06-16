- Feature Name: Safe Local Variable
- Start Date: 2016-06-15
- RFC PR:
- Pony Issue:

# Summary

The proposal aims at making Pony's type system aware that some data pointed by a variable doesn't leak the scope of that same variable, and thus will be able to prove that some local data moves are actually safe.

# Motivation

An issue with a iso or trn data, which have both write uniqueness, is that they don’t survive the call of a _pure_ function. A _pure_ function is a function which has no side effect, and thus shouldn't trouble the guarantees of a reference capability. But since Pony doesn’t know what happens to the data passed as arguments, to guarantee safety, Pony has to expects the worst, a data leak, even if it doesn’t actually happens.

Here is an example of an actor which count spaces and append it to the string being processed.
```
actor CountSpaceAppender

  be appendSpaceCount(s: String iso, callback: OtherActor) =>
    let n: USize = count(s)
    s.append(n.string())
    callback.send(consume s)

  fun count(s: String box): USize =>
    var n: USize = 0
    for c in s.values() do
      if c == ' ' then
        n = n + 1
      end
    end
    n
```

`count` doesn’t requires more than reading locally the string `s`. All ref caps passed as argument except `tag` could fit that requirement. But since it is an argument of a function, it must be an alias. So it still works for `box`, `val` and `ref`, but not for `iso` or `trn`.

Actually in this example the use of that alias doesn’t make its data leak. The parameter `s` is assigned to no other variable; it is not assigned to any field of the actor (its a box function); even if `s.values()` was exposing its data, it would only leak to another local variable `c`. And transitively the other variable `c` doesn’t leak either. The scope of the data represented by `s` is not goes outside its scope. So a `trn` or an `iso` variable could be passed: at end of the function the guarantee of the `iso` or `trn` are not transgressed.

A work around is to make the function give back the ownership of the arguments by returning them. For instance the previous example can be rewritten as:
```
actor CountSpaceAppender

  be appendSpaceCount(s: String iso, callback: OtherActor) =>
    (let n: USize, s) = count(consume s)
    s.append(n.string())
    callback.send(consume s)

  fun count(s: String iso): (USize, String iso^) =>
    var n: USize = 0
    for c in s.values() do
      if c == ' ' then
        n = n + 1
      end
    end
    (n, consume s)
```
But now the `count` function cannot be reused to handle a simple `String val` as argument.
And it starts to be painful if the data passed as argument is a field of a class, since it cannot be consumed. The field would have to be assigned of another value, either another `String` involving a memory allocation, or a `None` which make the typing of the field overwhelming (everywhere else in the code has to uselessly handle that the value might be `None`).

And there is the same issue with `trn` or `iso` data while calling `ref` functions on them. Some method needs to modify the state of their object, so they have to be `ref` functions, like `String.append()`. But if the argument is not sendable, like a `trn` one, this function won't be callable on an `iso` or a `trn`. Indeed, Pony doesn't know about the use of the arguments of a `ref` function, it has to expect the worst: the arguments will be leaking into the object. So to guarantee that the function doesn't break an `iso` or a `trn`, a `recover` will happen. It makes then impossible for a `trn` argument to be passed to a function of a `trn` object, even if the function doesn't do anything with the argument. To resume as an example, the following lines are a typing error even if it is safe to do so:
```
let s1: String iso = recover String.create() end
let s2: String iso = recover String.create() end
s1.append(s2)
```
Here the content of the data of `s2` is *copied* into `s1`, so after these lines, the data pointed by `s1` and `s2` are still referencing to different spaces in memory, and only these variable are pointing to it respectively.

This proposal is thus about helping Pony's type system to be able to prove the safety of such function calls.

# Detailed design

The data involved has to be declared as having a special restriction. This special restriction is about not leaking the scope of the variable. The details has to still be worked on, but the main idea that such typed data should not be able to be assigned to a field of an object nor sent to an actor.

There are two things which need to be declared to the Pony type system so that the previous examples would be provably safe:
- the caller has to declare that the data passed will have a restriction: it has the declare that the data is _borrowed_, the alias created for the purpose of the function call must not survive the lifetime of the function call.
- the argument of the function will have to be declared as _borrowed_, that the data represented by the variables won't be allowed to leak from the function.

## The syntax

The suggested design is to add a new keyword: `borrow` which would be used like `consume`. `borrow` will create a special kind of alias. So rather than using directly the variable as an argument of the function, it will have to be `borrow`ed. For instance:
```
let s: String iso = recover String.create() end
let n: USize = count(borrow s)
s.append(n.string())
```

Then the signature of the function will also declare the argument as _borrowed_. As the other ref cap modifiers a single character is suggested. The character `&` is avoided because in Rust (which also has data safety type system checker) `&` means the opposite of what is being declared here. Here `~` is suggested.

So the previous example would be written as follow:
```
fun count(s: String box~): USize =>
  [...]
```

## Typing Rules

### Passing and Sharing

A `~` alias is not sendable.

### Subtyping

Basically a `~` alias won't be assignable to anything other than another `~` alias.

TODO: study every kind of subtyping

### View Point Adaptation

To be check, but probably the rule will be about: any ref cap viewed via a `~` will be also seen as a `~` alias.

TODO: study every kind of view point

### Generics

TODO

# How We Teach This

This new ref cap modifier should be documented as well as the other ones.

# Drawbacks

This is a new ref cap modifier to know.

# Alternatives

## Borrow by default

Currently in Pony creating an alias by default create a `!` alias. The design suggested above add a new kind of alias: `~` ones which will be explicit via a `borrow` keyword.

When passing data as arguments, there are probably much more cases where the arguments are not leaked into caller object. And the default behavior could be chosen as the safer one for the caller, thus that the variable will be borrowed and will not leak. So it may be preferred to have by default borrowed alias, and have explicit data leaking.

So the previous example would be simply written as:
```
fun foo() =>
  let s: String iso = recover String.create() end
  let n: USize = count(s)
  s.append(n.string())

fun count(s: String box): USize =>
  [...]
```

```
let s1: String iso = recover String.create() end
let s2: String iso = recover String.create() end
s1.append(s2)
```

But then for functions which argument are part of a side effect:
```
class Array[A]
  var _ptr: Pointer[A]
  [...]
  fun ref update(i: USize, value: A!): A^ ? =>
    """
    Change the i-th element, raising an error if the index is out of bounds.
    """
    if i < _size then
      _ptr._update(i, consume value)
    else
      error
    end
```
And calling a side effect function will require an explicit alias creation, with a new syntax token; `alias` suggested here:
```
fun update_foo(i: USize, a: Array[String] iso) =>
  let s: String val = "foo"
  a.update(i, alias s)
```

# Unresolved questions

The current proposal is only studying function call. Probably it can be generalized at every kind of scope nesting.

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

TODO

# How We Teach This

TODO

# Drawbacks

TODO

# Alternatives

TODO

# Unresolved questions

TODO

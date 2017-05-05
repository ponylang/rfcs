- Feature Name: Safe Local Variable
- Start Date: 2016-06-15
- RFC PR:
- Pony Issue:

# Summary

The proposal aims at making Pony's type system aware that some data pointed by a variable doesn't leak the scope of that same variable, and thus will be able to prove that some local data moves are actually safe.

# Motivation

## Pure functions

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

Another work around is to use a `recover`:
```
be appendSpaceCount(s: String iso, callback: OtherActor) =>
  let s'' = recover
    let s': String ref = consume s
    n = count(s)
    s'.append(n.string())
    consume s'
  end
  callback.send(consume s'')
```
But the recover only allow `iso` data, `trn` are not allowed.

## Borrowed fields

When the data involved is a field of class, it becomes even more painful. The work around presented above are using `consumme`. Since a field cannot be consumed, so the only way to make it work is to make the field `None`-able. So the code will look like this:
```
actor CountSpaceAppender
  var s: (String iso | None) = recover String.create() end
  be append(s': String iso) =>
    try
      (s as String iso).append(consume s')
    else
      Debug.out("WAT?")
    end

  be appendCount() =>
    try
      (let n: USize, s) = count((s = None) as String iso^)
      (s as String iso).append(n.string())
    else
      Debug.out("WAT?")
    end

  fun count(s': String iso): (USize, String iso^) =>
    var n: USize = 0
    for c in s'.values() do
      if c == ' ' then
        n = n + 1
      end
    end
    (n, consume s')
```
Making the field an union type raise the issue about type cast, which is mandatory to handle in case of error. This make the code quite painful to read and write.

## Calling functions

And there is the same issue with `trn` or `iso` data while calling `ref` functions on them. Some method needs to modify the state of their object, so they have to be `ref` functions, like `String.append()`. But if the argument is not sendable, like a `trn` one, this function won't be callable on an `iso` or a `trn`. Indeed, Pony doesn't know about the use of the arguments of a `ref` function, it has to expect the worst: the arguments will be leaking into the object. So to guarantee that the function doesn't break an `iso` or a `trn`, a `recover` will happen. It makes then impossible for a `trn` argument to be passed to a function of a `trn` object, even if the function doesn't do anything with the argument. To resume as an example, the following lines are a typing error even if it is safe to do so:
```
let s1: String iso = recover String.create() end
let s2: String iso = recover String.create() end
s1.append(s2)
```
Here the content of the data of `s2` is *copied* into `s1`, so after these lines, the data pointed by `s1` and `s2` are still referencing to different spaces in memory, and only these variable are pointing to it respectively.

This proposal is thus about helping Pony's type system to be able to prove the safety of such function calls.

# Detailed design

In order to prove that the data move described in the previous part are safe, the type system has to be aware that the data involved is not leaking from its scope. The capabilities which are in motion here are just local ones, and is just about the ability to write or read. But in order to prevent the data from leaking its scope, there should be strict aliasing rules.

## 2 new reference capabilities

The suggested design introduce two new reference capabilities which will have the same capabilities as a `box` or `ref`; one for read, another for write. While the capabilities are quite relaxed, the lifetime of the data will be controlled by strict aliasing rules, way more strict than `box` and `ref`. So per se, it is not the capabilities which will ensure the data safety, but the aliasing rules. And these aliasing rules that the data is not leaking, and thus that other stricter reference capabilities like `iso` or `trn` and convertible into the two new ones.

The idea is that these new reference capabilities won't be used when creating objects, they are only intended to be used in a narrow scope. The other reference capabilities will be transformed temporary into these local ones. After these tricky data moves done on the local alias, the local variable goes out of scope, the original reference capability guarantees can still stand.

Thus, a new reference capability will be about declaring a local variable read only: `lro`. Another reference capability will be about local writable data: `lrw`.

## Capabilities

`lrw` can read and write, so it is denying read and write from other actors. `lro` can only read so is denying write but not read from other actors. But locally to the actor, `lrw` and `lro` are not denying anything.

A first simple subtyping rule, since `lrw` has just a write capability more than a `lro`, is: `lrw <: lro <: tag`

## Controlling the scope

To be able to control the scope of a `lrw` or a `lro` variable, fields of a class cannot be of a such reference capability, only actual _local_ binding are allowed.

And naturally, `lrw` and `lro` data are not sendable.

They can only be aliased as themselves, so that once a binding is declared _local_, every associated data is still _local_:
* `lrw! <: lrw`
* `lro! <: lro`

## Subtyping

When only considering reference capabilities, a `lrw` is not different from a `ref` and a `lro` is not different from a `box`, so the subtyping is rather simple:
* `iso <: trn <: ref <: lrw`
* `val <: box <: lro`

And consuming a _local_ variable just creat another _local_ variable, so simply:
* `lrw^ <: lrw`
* `lro^ <: lro`

## Borrow

Since `ref`, `val` and `box` are aliasing as themselves, it is simple to transform such data binding into local ones: aliasing is sufficient. But we need something for `iso` and `trn`.

Ephemeral types (`~`) and the alias types (`!`) can be viewed as types which describe the lifetime of the bindings involved. An ephemeral type has a lifetime of just an instruction, either an assignment or a call of a function; it also specifies that the lifetime of the aliased binding ends at the start of the new one. An alias type has a lifetime which is allowed to be infinite; and the lifetime of the aliased binding is not ended. Hence the present design is suggesting a third kind of lifetime: the current scope, of a function, or a loop, etc..., which suspends the lifetime of the aliased binding for the during of the temporary one.

A such _scoped_ lifetime would have then to be declared and used like ephemeral and alias types: it will be a reference capability modifier. As the other modifiers a single character is suggested. Rust which has a similar concept and uses `&`, but it is avoided because the semantic differs a little bit, Rust is about ownership and Pony is about deny capabilities. And `&` is confusing to people used to write C code. So here `~` is suggested.

Such scope-related type can be declared as such when it is an argument of a function. It will be up to the caller of the function to provide a such type. The caller will need to transform classical type into scoped one, via a special kind of aliasing. A new operator is needed, just like there is the `consume` operator. This operator will create from a binding another binding with special restrictions, the original binding will be _borrowed_. Hence the operator `borrow` is suggested.

The typing rules regarding borrow variable is then the following:
* `iso~ <: lrw`
* `trn~ <: lrw`
* `ref~ <: lrw`
* `val~ <: lro`
* `box~ <: lro`
* `tag~ <: tag`
* `lrw~ <: lrw`
* `lro~ <: lro`

Here is an example of use of `borrow`:
```
let s: String iso = recover String.create() end
let n: USize = count(borrow s)
s.append(n.string())
```

And the `count` function would be declared as such:
```
fun count(s: String lro): USize =>
  [...]
```

An important rule to maintain safety is that the lifetime of the aliased binding must be suspended of the duration of the scope of the new binding. Here is an example of code which *must* be prevented:
```
fun foo() =>
  let s: String iso = recover String.create() end
  bar(borrow s, consume s)
fun bar(s: String lrw, s2: String iso) =>
  another_actor.send(consume s2)
  s.append("bar") // <- this is not safe !
```

So, like the `consume` which acts on the aliased binding to destroy it, the `borrow` must act on the alias binding too. A `borrow` must forbid the use of the original binding during the lifetime of the new alias. For instance if it is an argument of a function, then the original can be reused only after the function call.

## View Point Adaptation

TODO

It will be probably about that anything view via a _local_ reference capability will also seen as _local_.

## Generics

TODO

Local reference capability doesn't make much sense in a type parameter. It should then be forbidden for now.

## Recovery

TODO

`lrw` and `lro` are not sendable, but do they actually break safety if it is possible ?

## Function call

TODO

what does it mean to call a `ref` function on a `lrw` or a `box` on a `lro`, is automatic recovery possible ?

## Function's return type

TODO

Intuitively a return type which is _local_ type doesn't make sense, since the role of returned is to leak. But maybe it would help on the contrary to specify that the data returned by the function is not that free to use, it should not leak and the ownership of that data should still be hold by called object. It would then be possible to wrap `iso` data into object and make them accessible via getters.

For instance, without local type this code won't compile:
```
class IsoWrapper
  let _s: String iso = recover String.create() end
  var _i: U32 = 0
  fun countAndGet(): String lrw =>
    _i = _i + 1
    borrow _s
```

It seems a fragile design though. It's probably safer to just forbid it for now.

## Default reference capability

TODO

It doesn't seem to make sense that a default reference capability for a type to be a _local_ one. On the other hand it is just a default, it is just a kind of shortcut for Pony coders.

It's probably safer to just forbid it for now.

# How We Teach This

This new references capabilities should be documented as well as the other ones. A dedicated page in the tutorial will be needed.

# Drawbacks

These are new reference capabilities to know for the Pony users.

These will inevitably add more cases to handle into the type checker.

# Alternatives

Some were studied but were not working, see the history of this RFC to read them.

# Unresolved questions

The current proposal is only studying function call. Probably it can be generalized at every kind of scope nesting, like local variables in loops.

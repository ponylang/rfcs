- Feature Name: explicit_self_member_access
- Start Date: 2020-05-24
- RFC PR:
- Pony Issue:

# Summary

This RFC removes the syntax for assuming `this.` implicitly when referencing fields and methods of the current object, in order to remove the namespace collision with local variables and parameters. It introduces a new syntax that can be used to conveniently and succinctly specify the concept of `this.` now that it will have become explicitly required.

# Motivation

In current Pony syntax, if a bare identifier is referenced (with no leading token indicating its receiver or scope), it could either refer to something in the local scope (i.e. local variable or parameter) or it could refer to a member (i.e. a field or method) of the `this` object (that is, it is syntax sugar in which the compiler treats the identifier as if an implicit `this.` preceded it).

This latter option is meant to be a handy convenience - the idea being that almost all types will have reason to access their own fields and methods quite a lot, so it makes sense to optimize for this case and make the syntax for doing so very convenient. However, the unfortunate consequence of this approach to convenience is that it introduces collision concerns between names of local identifiers (the internal implementation details of the type) and names of member identifiers (the "shape" or interface of the type).

Such collisions would normally result in implicit shadowing, but the Pony compiler prevents shadowing of this kind by raising a compilation error if any local variable has the same name as a field or method of the type. In practice, this leads to a lot of frustration among newcomers and veterans of the language alike.

The main frustration appears to come from the way this collision sort of behaves like "action at a distance" - introducing a new field or method in the type may force a refactor for anywhere the same name may have been used as a parameter or local variable name in the methods of that type, even for those methods that do not use any such fields. In such a case, the programmer will usually add the prime character (a single quote following the identifier) so that it becomes a unique identifier with (mostly) the same name:

```pony
class Greeting
  var _message : String
  new create(message': String) => _message = message'
  fun message(): String => message'
```

One trouble with such refactors is that they seem to constitute "extra busywork" for the programmer. Another more serious problem is that any such
refactor (adding a prime suffix to a parameter name), while it may not appear on its face to be a breaking change, it will break any call sites that are using the "named arguments" syntax with the old (non-primed) name.

In order to prevent such refactors, many Pony veterans have adopted a sort of pre-emptive pattern in which they use prime-suffixed parameter names even when they are not strictly needed. This works but I cannot personally bring myself to call it a best practice because it feels more like a kind of walking on eggshells behavior learned from a recurring pain point, and it may even appear overly "superstitious" to those who have not yet felt the pain as much as others have.

# Detailed design

The change proposed in this RFC will remove the possibility of implicitly referencing "this" as the receiver object of a method call or a field. As such, every lowercase identifier with no leading token indicating its receiver or scope will be treated as referring to a local variable or parameter. This eliminates the namespace collision between local scope and member names of the type, so there will also no longer be a compiler error that prevents declaring a local variable or parameter with the same name as a method or field.

To retain a high level of convenience for the very common use case of calling methods or accessing fields of the current receiver for the method scope, this RFC proposes to introduce the `@` symbol as a one character prefix that will serve to represent `this.` when used at the start of an identifier. Additionally, the `@` symbol when used alone (not attached to another identifier) would represent the object `this`.

Here is a small compilable example demonstrating a class (`Greeting`) that has a parameter (`message`) with the same name as one of its field, and an actor (`Main`) that has a local variable (`greet`) with the same name as one of its methods. The example shows that that the two can be easily differentiated by the reader without needing to know ahead of time which methods or fields exist on the type:

```pony
class Greeting
  var message: String
  new create(message: String) => @message = message
  fun print(name: String, out: OutStream): String =>
    out.print(@message + ", " + name)

actor Main
  new create(env: Env) =>
    let greet = Greeting("Hello")
    @greet(greet)

  fun ref greet(greet: Greeting, out: OutStream) =>
    greet.print("World", out)
```

Under this system, the "at" symbol can be thought of mnemonically as referring to "the object where this code is executing *'at'*". Additional prior art is in the Coffeescript language, [where this symbol is used](https://coffeescript.org/#operators) in exactly the same way as it is being proposed here. Ruby and Crystal use `@` in a similar way as a prefix for fields, though they do not use it for methods and they have the local vs object scope namespace collision problem described in this RFC - they allow silent shadowing rather than raising a compiler error as Pony does.

Obviously, at this time, the `@` symbol is used for FFI and for bare function definitions. Another RFC will be proposed to change the syntax for those constructs which would "make room" for using the `@` symbol in the way described by this RFC. Arguably FFI and especially bare functions are much less frequently used than this syntax would be, which I personally believe is a good justification for freeing up this symbol to be used by a new feature that would be used in almost every Pony function (explicit self member access). Any objections to changing the syntax of FFI and bare function calls can be discussed in the context of the other RFC rather than here.

For many more syntax examples, see [the `.mare` files in the Mare compiler's codebase](https://github.com/jemc/mare/tree/master/src/prelude), where this syntax already exists and is parsed by the parser, along with the other syntax changes included there. This RFC and others to come are attempting to try to get some general consensus agreement on the desireability of at least some of the syntax changes that have been introduced in that work.

# How We Teach This

Nearly all tutorials, examples, and standard library code would need to be modified to comply with this change.

Additionally, we should provide some form of automated tooling to help with porting old code.

# How We Test This

All existing standard library code and compiler tests would verify the new syntax.

The Mare compiler has successfully been using this new syntax already and has tested that it works without issue, and actually makes the compiler code simpler than it was before introducing it.

# Drawbacks

* This breaks nearly all existing code.
* Many call sites will become slightly more verbose (adding an extra character in front of many identifiers) by removing the implicit ambiguity of scope.
* Using `@` as a symbol will require other syntax interventions to change FFI calls and bare functions (another RFC will be filed to discuss these interventions).

# Alternatives

- Remove the implicit `this.`, but don't introduce any new syntax for `this.`, which would remove the namespacing problem at the expense of a lot of extra reading and typing for everyone.
- Use a different succinct syntax to indicate `this.`, rather than the `@` character.
- Don't do any of this, and leave the existing problems in place.

# Unresolved questions

- None at this time.

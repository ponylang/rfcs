- Feature Name: explicit_self_member_access
- Start Date: 2020-05-24
- RFC PR:
- Pony Issue:

# Summary

The syntax change would allow a field to be referenced in the position of a parameter, indicating that the argument passed for that parameter position should be immediately assigned to the field rather than given its own name in the local scope.

# Motivation

In current Pony syntax, there can be significant code redundancy required to build simple data classes that take the arguments of their constructors and simply assign them to the field of the same name.

One must declare the field, with its name and type, then declare the parameter with the same name and type in a particular position, then write an assignment statement in the body of the method.

Consider the following real-world code example from the `ponycc` repository, in which a simple data class with six fields requires 22 lines of code with redundant type information, just to get the class off the ground with a constructor and before writing any useful methods:

```pony
class val UseFFIDecl is (AST & UseDecl)
  let attachments: (Attachments | None)
  let name: (Id | LitString)
  let return_type: TypeArgs
  let params: Params
  let partial: (Question | None)
  let guard: (IfDefCond | None)

  new val create(
    name': (Id | LitString),
    return_type': TypeArgs,
    params': Params,
    partial': (Question | None),
    guard': (IfDefCond | None) = None,
    attachments': (Attachments | None) = None)
  =>
    this.attachments = attachments'
    this.name = name'
    this.return_type = return_type'
    this.params = params'
    this.partial = partial'
    this.guard = guard'
```

# Detailed design

The change proposed in this RFC introduces "assign parameters", which allow a field to be referenced in the position of a parameter, indicating that the argument passed for that parameter position should be immediately assigned to the field rather than given its own name in the local scope.

Each field will be referenced with its `this.`-prefixed identifier, just as it would be referenced in the body of a method (though unlike in that context, the `this.` prefix would be required rather than optional here). Here is the same example from above, rewritten now in just 9 lines compared to the earlier 22:

```pony
class val UseFFIDecl is (AST & UseDecl)
  let attachments: (Attachments | None)
  let name: (Id | LitString)
  let return_type: TypeArgs
  let params: Params
  let partial: (Question | None)
  let guard: (IfDefCond | None)

  new val create(this.name, this.return_type, this.params, this.partial, this.guard, this.attachments) => None
```

Note that there is now no syntactical body of the method apart from the obligatory `None` expression, and the compiler will add a body that does the appropriate assignments.

Of course, "assign parameters" can be used alongside normal parameters, and not every field need be associated to an "assign parameter". Assign parameters can also have a "default value" as normal parameters can, which specifies the value to use if the caller does not supply an argument for that position. The following refactored example demonstrates all of those concepts:

```pony
class val UseFFIDecl is (AST & UseDecl)
  let attachments: (Attachments | None)
  let name: (Id | LitString)
  let return_type: TypeArgs
  let params: Params
  let partial: (Question | None)
  let guard: (IfDefCond | None)

  new val create(name: String, this.return_type, this.params, this.attachments = None) =>
    this.name = Id(name)
    this.partial = None
    this.guard = None
```

As you can see, this syntax opens new opportunities but shouldn't preclude any old ones. Thus, it is not a breaking change or required learning, and it merely offers convenience for those looking for it. There are no new keywords or symbols needed in the parser.

## Compiler implementation discussion

Internally, the names of these parameters are anonymous/hygienic ids, meaning that they cannot be used by any explicit code and will not collide with any such names - they are are anonymous references that are immediately assigned at the beginning of the function body.

Note that they must also be `consume`d in the assignment, so that the assignment will work properly for `iso`- and `trn`-typed fields. Again, this is an internal implementation detail just to make it behave as the user expects.

One additional implementation wrinkle is how to handle the case of non-sendable field caps being used as assign params to functions/constructors that allow only sendable parameters. For example, the case of an `ref` field  on an assign param of an actor's constructor. In this case, the assign param cannot be the same cap as the field as it usually would be, since `ref` parameters are not sendable to the actor's constructor. Instead we must "lift" the cap of the assign param to the "nearest" sendable cap that can be assigned to that field cap - in this case, it would be `iso`. This follows the principle of least surprise because this is exactly what the programmer would have to do explicitly to make such a code pattern work properly with capabilities.

# How We Teach This

Add a new section to the tutorial to teach this.

Change some of the standard library to demonstrate it in action.

# How We Test This

New compiler tests that demonstrate this case, including the edge cases mentioned in the implementation details above.

# Drawbacks

* New patterns to learn (though no codebases will be required to use these patterns, you have to learn the new patterns if you want to write or read code that uses them).
* Added compiler complexity.

# Alternatives

- Don't do any of this, and leave the existing verbosity in place.

# Unresolved questions

- None at this time.

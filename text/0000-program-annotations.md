- Feature Name: program-annotations
- Start Date: 2016-10-31
- RFC PR:
- Pony Issue:

# Summary

Add a way to annotate arbitrary elements in the source code with arbitrary strings. The annotations would be added to the Abstract Syntax Tree (AST) by the parser. The compiler and third-party AST processing tools could then look for those annotations and take various actions.

# Motivation

This system would be useful to implement new language constructs that don't need new keywords or syntax. An example of this is the [branch prediction](https://github.com/ponylang/rfcs/pull/44) construct. Also, since the AST format will be fully specified in the future, third-party tools could use user-defined annotations to implement complex AST transformations.

# Detailed design

The proposed syntax for annotations is

```text
\annotation1, annotation2, ...\
```

An individual annotation can be any valid identifier (i.e. anything that can be used as a variable or type name). Annotations and variables/types using the same identifier aren't linked in any way. The annotation list is agnostic to whitespace and can span multiple lines.

At the source code level, annotations are attached to their right-hand side construct and cover as much as possible. The annotated construct must be valid on its own. Any construct in the language can be annotated, it is the responsibility of the compiler and third-party tools to use sane locations.

Some examples of annotations:

- `\foo\ (2 + 3) * 5`: `(2 + 3) * 5` is annotated
- `(2 + \foo\ 3) * 5`: `3` is annotated
- `(2 + 3) \foo\ * 5`: invalid, `* 5` isn't a valid construct in isolation.

At the parser and AST level, the parser optionally processes a list of annotations before handling the upcoming rule and attaches the annotations to the resulting AST.

# How We Teach This

The feature would be introduced with a general section on annotations in the tutorial. We would also describe the compiler-specific annotations in the tutorial and/or Pony patterns. Documentation for user-defined annotations would be up to the third-party tool handling them.

It could also be useful to warn about the possibly surprising behaviour of annotations when used near "phantom" language constructs. For example, the annotation in the following program would be attached to the AST for the whole file and not to the AST for `Foo`.

```pony
\foo\
actor Foo
  new create() => None
```

# How We Test This

Verifying that annotations are indeed showing up in ASTs at the right places should be enough.

# Drawbacks

Since annotations can be used anywhere, very ugly code can be written. This wouldn't have any influence on correctness or performance since only specific annotations in specific places would actually be handled.

# Alternatives

Don't add this system and continue adding new syntax for every new language construct. If the feature is minor, it can be more complex to add new syntax than to use annotations.

# Unresolved questions

None.

- Feature Name: program-annotations
- Start Date: 2016-10-31
- RFC PR: https://github.com/ponylang/rfcs/pull/64
- Pony Issue: https://github.com/ponylang/ponyc/issues/1442

# Summary

Add a way to annotate elements in the source code with arbitrary strings. The annotations would be added to the Abstract Syntax Tree (AST) by the parser. The compiler and third-party AST processing tools could then look for those annotations and take various actions.

# Motivation

This system would be useful to implement new language constructs that don't need new keywords or syntax. An example of this is the [branch prediction](https://github.com/ponylang/rfcs/pull/44) construct. Also, since the AST format will be fully specified in the future, third-party tools could use user-defined annotations to implement complex AST transformations.

# Detailed design

The proposed syntax for annotations is

```text
\annotation1, annotation2, ...\
```

An individual annotation can be any valid identifier (i.e. anything that can be used as a variable or type name). Annotations and variables/types using the same identifier aren't linked in any way. The annotation list is agnostic to whitespace and can span multiple lines.

Annotations can occur after any scoping keyword or symbol:

- `actor`
- `class`
- `struct`
- `primitive`
- `trait`
- `interface`
- `new`
- `fun`
- `be`
- `if` (not in a guard)
- `ifdef`
- `iftype` (not in a guard)
- `elseif`
- `else`
- `while`
- `repeat`
- `for`
- `match`
- `|` (as a case in a `match` expression)
- `recover`
- `object`
- `{` (for lambdas)
- `with`
- `try`
- `then` (only when part of a `try` block)

Annotations are attached to the AST for the keyword/symbol they follow. 

Some examples of annotations:

- `if \likely\ foo then ... end`
- struct \packed\ Bar`

## Note on the implementation

Annotations shouldn't be added as sub-ASTs by the parser to avoid breaking existing AST processing in the compiler.

# How We Teach This

The feature would be introduced with a general section on annotations in the tutorial. We would also describe the compiler-specific annotations in the tutorial and/or Pony patterns. Documentation for user-defined annotations would be up to the third-party tool handling them.

# How We Test This

Verifying that annotations are indeed showing up in ASTs at the right places should be enough.

# Alternatives

Don't add this system and continue adding new syntax for every new language construct. If the feature is minor, it can be more complex to add new syntax than to use annotations.

# Unresolved questions

None.

- Feature Name: class-and-actor-field-docstrings
- Start Date: 2017-12-22
- RFC PR: https://github.com/ponylang/rfcs/pull/115
- Pony Issue: https://github.com/ponylang/ponyc/issues/2502

# Summary

This RFC suggests adding docstrings to fields of classes and actors
in order to make necessary documentation avaliable on them.
This is especially important for public fields of classes.

# Motivation

Docstrings are currently only allowed on type-, class-, actor, function- and behavior-definitions.
But for usage of certain classes it is important to know something about their fields too,
as they can also be exposed publicly.

One example class that definitely needs to have its fields documented is: [net.NetAddress](https://github.com/ponylang/ponyc/blob/main/packages/net/net_address.pony) which needs some documentation stating that e.g. the field `port` is in network byteorder. This information is not available at the moment and leads to confusion. Putting this information into the class docstring is not a satisfying solution here.

The exepected outcome is to have the docstring for each field of a class or actor rendered in the `Public Fields` and `Private Fields` section below their field names and types.

# Detailed design

A field-docstring comes after the field definition and  to be consistent with other existing docstring placements and to avoid ambiguities within the parser:

```pony
class MyClass
  """class docstring"""

  let number: U32
  """field docstring"""

  let name: String = "Rainbow Dash"
  """fields docstring"""

  fun method(arg: String): None =>
    """method docstring"""
    None
```

The parser rule for class or actor fields needs to be changed to include an optional rule for a docstring:

```c
// (VAR | LET | EMBED) ID [COLON type] [ASSIGN infix]
DEF(field);
  TOKEN(NULL, TK_VAR, TK_LET, TK_EMBED);
  MAP_ID(TK_VAR, TK_FVAR);
  MAP_ID(TK_LET, TK_FLET);
  TOKEN("field name", TK_ID);
  SKIP("mandatory type declaration on field", TK_COLON);
  RULE("field type", type);
  IF(TK_ASSIGN, RULE("field value", infix));
  OPT TOKEN("docstring", TK_STRING);
  DONE();
```

The actual implementation might differ if this solutions is not feasible for some unforeseen reason.

The AST node for a field will have a new optional last child:

(TK_FVAR | TK_FLET | TK_EMBED (TK_ID "field_name") type assignment "field docstring")

As far as I can see only the docgen pass is interested in this docstring.

# How We Teach This

These new docstrings should be called field-docstrings.

The tutorial should have a section about documenting pony code, which consists of a how-to about:

- how to document pony code, syntactically (where to place docstrings, docstrings being parsed as markdown, ...)
- what good documentation should cover (maybe)
- How to generate documentation in html from you pony code.

This section should mention that docstrings can also be attached to fields and show examples of how to do it.

# How We Test This

The Acceptance criteria for this RFC is on the one hand a bunch of compiler unit tests that ensure that docstrings below fields do not interfere with other fields or members coming after them and are also properly parsed as docstrings if the field is defined as last element of a class or actor.

On the other hand it should be ensured that the stdlib documentation is rendering the docstrings as proper markdown as it currently does for all other docstrings.

# Drawbacks

- Increased AST size due to additional docstrings
- More code in docgen pass to handle field documentation
- Longer documentation pages per class / actor - this could hurt both clarity and brevity

# Alternatives

Besides not having field docstrings at all there are the following alternatives:

- Syntactically the docstring could also go right above the field definition, but this is ambiguous in case an empty method is defined right above. Should the docstring belong to the method above or the field below?
- Also a docstring between field definition and (optional) assignment would be possible, but this is rather incenvenient to read as it splits the field code into two parts that are harder to grasp that way. Example:

```pony
let field: String """docstring""" = "value"

let another_field: U8
"""
docstring
"""
= 0
```

- Provide a docstring syntax for documenting fields and put this into the class/actor docstring. This would require a little kind of language for parsing the field documentation from a docstring and would make the docgen code a lot more complicated. Also, when reading code it is much more convenient to have the docstring right next to the actual code that is being documented. This would not be the case with this alternative.


# Unresolved questions


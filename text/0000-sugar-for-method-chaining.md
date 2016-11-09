- Feature Name: Sugar for method chaining
- Start Date: 2016-05-30
- RFC PR:
- Pony Issue:

# Summary

Lots of APIs support method chaining, but in Pony (and most languages) this needs explicit support in the class implementation. This is a proposal to introduce a syntax sugar for invoking a method such that the return value is discarded and replaced with the object itself allowing further operation.


# Motivation

It can be useful to invoke multiple methods on the same model. An example is a configuration objct where the methods change or setup a part of the configuration.

Rather than requiring API designers to wire this capability into the method return value in the form of returning ``this`` explicitly, this proposal is to use a special syntax to make it work in the general case.

Methods such as ``Map.compact`` can be simplified by not having to declare and return ``this`` and some methods can return more useful return values without breaking the option to do method chaining.

Note that this change also makes it clear that the returned object is in fact not a modified copy of the original object, but the same object. This helps promote the idea that in Pony, objects are immutable only by reference capability and not inherent design.


# Detailed design

The proposed syntax to invoke a method for chaining is ``object.>method``.

When using the method chaining sugar, the existing return value is discarded and replaced with a reference to `this`.

The following semantics apply:

* If the receiver type can alias as itself, the chained type doesn't change;
* If the receiver type is a non-ephemeral unique type (iso, trn or #send), the call was necessarily recovered so it is safe to chain the same type;
* If the receiver type is an ephemeral unique type:
  * If the call was recovered, if the method capability is the non-ephemeral type, or if the non-ephemeral type is a subtype of the method capability (i.e. tag method for iso object or box method for trn object), the chained type is the ephemeral type.
  * Else, the chained type has the same capability as the method capability.

# How We Teach This

In the tutorial there will be a new section under "Methods" that motivates and explains this syntax.


# Drawbacks

This adds additional syntax to the language. Users will have to understand the meaning of the new notation.

This is also a breaking change although existing code can easily be updated with the new syntax.


# Alternatives

Other syntax options were discussed such as ``object->method`` which has the problem that this syntax is already used for view adaptation and ``object:method`` which was considered to be visually hard to distinguish from a regular method call.


# Unresolved questions

None.

- Feature Name: JSON Viewpoint Getters
- Start Date: 2021-11-18
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Introduce "getters" into the JSON package. Specifically access methods for
`data` in `JsonDoc`, `JsonObject` and `JsonArray`.

# Motivation

Currently the interaction between the JSON API and the Pony reference
capability type system makes it difficult to work with JSON documents that need
to be mutated after they have been created.

By introducing getter methods it will be possible to leverage viewpoint
adaptation to enable mutations when the caller site holds a mutable reference,
but to enforce immutability when the calling alias is a `val` or `box`.

Additionally, a caller with an `iso` reference will be able to perform
mutations to the document and then recover and `iso` reference afterwards.

# Detailed design

The implementation consists of using the `apply()` style access to introducing
three getters, into `JsonDoc`, `JsonObject` and `JsonArray` respectively:

- document data access: `fun apply(): this->JsonType! => ...`,
- object data access: `fun apply(): this->Array[JsonType]! => ...`,
- array data access: `fun apply(): this->Map[String, JsonType]! => ...`.

These access methods can then be used via direct calls or via syntactic sugar
calls.

# How We Teach This

The examples in the JSON inline documentation can be extended or changed to
demonstrate the usage of the getter methods.

The access methods, themselves, will be documented.

# How We Test This

Unit tests that cover both mutable access and immutable access, as well is the
recovery of `iso` documents after mutation.

# Drawbacks

This is a purely additive change, so it does not incur in major risk in terms of
existing code. Additionally, the code complexity is low and should be easy to
maintain.

## Uptake and entrenchment

However, if there is uptake following these additions, the approach will likely
become entrenched, and therefore difficult to revert. Therefore, we need to be
comfortable with this approach going forward.

## Syntactic sugar oddities

By relying on the `apply()` syntactic sugar it is possible to write expressions
that are a little contrived:

```pony
(jdoc_ref() as JsonObject)()("other_stuff") = "hello"
```

which might be more easily read if written as:

```pony
(jdoc_ref() as JsonObject).apply()("other_stuff") = "hello"
```

# Alternatives

The basic approach of adding "getter" access methods seems quite reasonable.
However, the issue of method naming is really the point where alternative could
be considered.

## The current recommendation

A purely additive change using the `apply()` syntactic sugar for access. This
allows one to write:

```pony
try
  let obj = (json_doc() as JsonObject)
  obj()("more") = "stuff"
end
```

## Additionally include `update()`

That is, include an `update(value: JsonDoc): this->JsonType! => ...` method to
allow for setting the underlying `data` field.

## Convert the `data` field to private

The above recommendation is a non-breaking change. Therefore, the current `data`
field, which is public has be left as-is. However, it might be better
standardise on using the access methods and make the data field private. That
is, rename the field to:

- `_data`

The drawbacks of this approach are:

- it becomes a breaking change for all existing code,
- it would require the addition of a setter (such as introducing `update(...)`).

## Use `data()` as the access method

If make the data field private, we can consider using `data` as the access
method name. In this case we would not provide the syntactic sugar, but we would
still solve the core problem of data mutation.

However, the drawback of this approach is that a separate "setter" may be
needed.

## Dual access with `apply()` and `data()`

Given that the syntactic sugar approach can sometime look odd, we could consider
providing both `apply()` and `data()`. However, the drawbacks of this approach
are:

- it burdens the API user with the choice of calling `data()` or using the sugar
  (or even calling `apply()`,
- it would still require providing a setter of some form.


# Unresolved questions

Should a deeper design review be carried out? Otherwise, the alternatives,
above, should cover the bulk of the potential questions.

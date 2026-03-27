- Feature Name: json-encode-jsonvalue
- Start Date: 2026-03-12
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Adapt the stdlib [`json` package][json-package] in order to add means to encode arbitrary [`JsonValue`][JsonValue]s into `String` or `Array[U8]`. And while we are at it, provide a matching API for decode `String` or `Array[U8]` into [`JsonValue`] for completeness.

# Motivation

The basic functionality of a json library should be to provide a representation for structured json values (which is [JsonValue][JsonValue]) and methods to decode a string or bytes as JSON into this [JsonValue][JsonValue] and vice versa, to encode all possible representations of [JsonValue][JsonValue] into valid JSON bytes (or string). The current [`json` package][json-package] is lacking the means of encoding all [JsonValue][JsonValue] instances into valid JSON.

`JsonObject` and `JsonArray` provide methods for encoding them as valid JSON with the `.string()` and `.pretty_string()` methods, but for all other possible JSON values (string, number, bool, null) there is no such method. The `.string()` method on `None` is producing `"None"` (without the quotes), which is invalid JSON. Another example: the String `"\""` is copying itself when `.string()` is called on it, without any escaping, which is also invalid JSON. The method `.pretty_string()` is missing from all those other [JsonValue][JsonValue] instances.

This package needs a consistent and convenient way to encode and decode json bytes from and to all possible [JsonValue][JsonValue] instances.

# Detailed design

This PR suggests adding a new primitive called `Json`:

```pony
primitive Json
  fun print(value: JsonValue, pretty: Bool = false): String =>
    if pretty then
      _JsonPrint.pretty(value)
    else
      _JsonPrint.compact(value)
    end

  fun parse(source: String): (JsonValue | JsonParseError) =>
    JsonParser.parse(source)
```

All the bits and pieces for encoding arbitrary values are there already, they just aren't exposed. `_JsonPrint` is private.

The naming of the functions is not settled yet. The dual of `encode` and `decode` would be ideal, but the `JsonParser` already returns `JsonParseError`, hence `parse` makes more sense for the decoding step, but it lacks a proper dual name for the process of decoding. For further discussion of the naming, see [Alternatives](#alternatives).

Proper docstrings are missing, obviously. They should explain what can be expected, under which conditions errors are raised etc. and also list usage examples. They were left out for brevity.

We might want to remove the `JsonObject.string()` and `JsonArray.string()` (and `.string_pretty()`) functions. As all [JsonValue][JsonValue] members implement `ToString` and thus all have a `.string()` method, but don't all produce valid JSON, this might be a source of confusion. This would also shrink the amount of different ways to achieve one thing to one: `Json.print()`.

The `JsonParser` primitive should also be removed and the contents of its `parse()` method should be moved to the `Json.parse()` method, to have only one way of decoding a string as JSON.

# How We Teach This

The package documentation of the `json` package should show usage examples of these functions most prominently and then show all other components of the crate, like `JsonValue`, `JsonPath` or `JsonNav`.

The intend of this primitive is to expose an easy-to-use interface for turning strings into structures JSON values and vice versa. This should answer the question of how to get from bytes or strings from the network or from files to structured JSON that can be analyzed (Pass the string to `Json.parse()`), and how to serialize Pony objects and data-structures as JSON (build a `JsonValue`, then pass it those `Json.print()`).


# How We Test This

Additional property-based tests will be added for encoding arbitrary [JsonValue][JsonValue]s via `Json.encode(...)` and parsing them again via `Json.parse(...)` and ensuring equivalence of the initial values and the ones produces by the roundtrip.

# Drawbacks

While exposing a way of printing/encoding/serializing [JsonValue][JsonValue]s is necessary, removing `JsonParser` and `JsonObject.string` etc. might not be. These changes are breaking.

# Alternatives

Function naming alternatives:

- `parse` / `print` - this would follow the existing naming in the package the closest, hence considered as the best candidate.
- `encode` / `decode` - this pair would make sense if the decoding would not expose `JsonParseError`. It feels inconsistent to create a `ParseError` from a `decode` function call.
- `serialize` / `deserialize` - these terms are not used anywhere yet in pony, so didn't favor them.
- `to_string` / `from_string` - The most humble variant of them all, getting along without any fancy terminology.

# Unresolved questions

- Should a partial version of parsing be also exposed?
- Should `Json.print()` expose finer controls than just the `pretty` flag?

[json-package]: https://github.com/ponylang/ponyc/tree/main/packages/json
[JsonValue]: https://github.com/ponylang/ponyc/blob/main/packages/json/json.pony#L243

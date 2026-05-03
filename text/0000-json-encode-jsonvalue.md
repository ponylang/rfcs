- Feature Name: json-encode-jsonvalue
- Start Date: 2026-03-12
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Adapt the stdlib [`json` package][json-package] in order to add a `JsonPrinter` primitive exposing functions to encode arbitrary [`JsonValue`][JsonValue]s into `String iso^`, in a similar manner as the existing `JsonParser` for parsing [`JsonValue`][JsonValue] from String.

# Motivation

The basic functionality of a json library should be to provide a representation for structured json values (which is [JsonValue][JsonValue]) and methods to decode a string or bytes as JSON into this [JsonValue][JsonValue] and vice versa, to encode all possible representations of [JsonValue][JsonValue] into valid JSON bytes (or string). The current [`json` package][json-package] is lacking the means of encoding all [JsonValue][JsonValue] instances into valid JSON.

`JsonObject` and `JsonArray` provide methods for encoding them as valid JSON with the `.string()` and `.pretty_string()` methods, but for all other possible JSON values (string, number, bool, null) there is no such method. The `.string()` method on `None` is producing `"None"` (without the quotes), which is invalid JSON. Another example: the String `"\""` is copying itself when `.string()` is called on it, without any escaping, which is also invalid JSON. The method `.pretty_string()` is missing from all those other [JsonValue][JsonValue] instances.

This package needs a consistent and convenient way to encode and decode json bytes from and to all possible [JsonValue][JsonValue] instances.

# Detailed design

This PR suggests adding a new primitive called `JsonPrinter`:

```pony
primitive JsonPrinter
  """
  Serialize any `JsonValue` to a JSON string.
  """
  fun print(value: JsonValue): String iso^ =>
    """Compact JSON serialization of any `JsonValue`."""
    _JsonPrint.compact(value)

  fun pretty(value: JsonValue, indent: String = "  "): String iso^ =>
    """Pretty-printed JSON serialization of any `JsonValue`."""
    _JsonPrint.pretty(value, indent)
```

All the bits and pieces for encoding arbitrary values are there already, they just aren't exposed. `_JsonPrint` is private.

To avoid confusion and misuse, the methods `JsonObject.string()` and `JsonArray.string()` (and `.string_pretty()`) are being renamed to `JsonObject.print()`, `JsonArray.print()` and `JsonObject.pretty_print()`, `JsonArray.pretty_print()`. This has the side-effect of both `JsonObject` and `JsonArray` and thus `JsonValue` not implementing `Stringable` anymore.

# How We Teach This

The package documentation of the `json` package should show usage examples of the new `JsonPrinter` functions as prominently as `JsonParser` usage and then show all other components of the crate, like `JsonValue`, `JsonPath` or `JsonNav`.

The intend of this primitive is to expose an easy-to-use interface for turning JSON values into strings as a dual to `JsonParser`. This should also answer the question of how to serialize Pony objects and data-structures as JSON (build a `JsonValue`, then pass it to `JsonPrinter.print(value)`).


# How We Test This

Additional property-based tests will be added for encoding arbitrary [JsonValue][JsonValue]s via `JsonPrinter.print(...)` and parsing them again via `JsonParser.parse(...)` and ensuring equivalence of the initial values and the ones produces by the roundtrip.

# Drawbacks

Renaming `.string()` and `.string_pretty()` on `JsonObject` and `JsonArray` to `.print()` and `.pretty_print()` is a breaking change. It will cause libraries and applications using the `json` package to be changed in order to be compiled with the ponyc version containing this change.

# Alternatives

Function naming alternatives for parsing/printing:

- `parse` / `print` - this would follow the existing naming in the package the closest, hence considered as the best candidate.
- `encode` / `decode` - this pair would make sense if the decoding would not expose `JsonParseError`. It feels inconsistent to create a `ParseError` from a `decode` function call.
- `serialize` / `deserialize` - these terms are not used anywhere yet in pony, so didn't favor them.
- `to_string` / `from_string` - The most humble variant of them all, getting along without any fancy terminology.

Note that this RFC only includes `print` in scope, so renaming the `parse` would be out of scope unless we decided to pursue one of the above alternatives for a broader change.

# Unresolved questions

- Should the options, like pretty-printing or not, be exposed as optional parameters to `JsonPrinter.print()` instead of exposing `.print()` and `pretty()`?

[json-package]: https://github.com/ponylang/ponyc/tree/main/packages/json
[JsonValue]: https://github.com/ponylang/ponyc/blob/main/packages/json/json.pony#L243

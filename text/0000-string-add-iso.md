- Feature Name: Make String.add return String iso^
- Start Date: 2021-04-19
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

This RFC aims to change the signature of the [`String.add`](https://stdlib.ponylang.io/builtin-String/#add) method to return `String iso^`, instead of `String val`.

# Motivation

The current `Stringable` interface requires implementing a `string()` method that returns `String iso^`. If one wishes to implement the `Stringable` interface for a custom type such as the following:

```pony
class MyClass is Stringable
  let var1: String = "hello"
  let var2: String = " world"

  fun string(): String iso^ =>
    var1 + var2
```

The compiler will complain that the return type of `string()` is `String val`. A correct version of the code would be:

```diff
   fun string(): String iso^ =>
-    var1 + var2
+    recover
+    String.create(var1.size() + var1.size())
+      .>append(var1)
+      .>append(var2)
+    end
```

The code, while correct, is overly verbose. It's also similar to the [internal implementation](https://github.com/ponylang/ponyc/blob/dec0b68d927ec7c5b84d7c5046061baf97cd8ebd/packages/builtin/string.pony#L1304-L1310) of `String.add`.

By changing the return type of `String.add` to `String iso^`, the original code, which is more straightforward, becomes valid.

# Detailed design

The return type of `String.add` will be changed to `String iso^` and the code using this method will be updated in case it is relying on type inference to infer the reference capability of the String to be `val`. This should boil down to add a few recover or consume calls here and there in the stdlib and the examples.

# How We Teach This

The documentation should be updated, and a proper changelog note should be added to the `ponyc` release notes.

# How We Test This

No new tests would be needed with this change. Existing tests that depend on the current return capability would need to be updated.

# Drawbacks

* Breaks existing code

# Alternatives

* Leave the current signature of `String.add` as it is.
* Add an additional method to `String` that performs the same functionality as `add`, but returns `String iso^`.

# Unresolved questions

None.

- Feature Name: iter-maybe
- Start Date: 2020-04-21
- RFC PR: https://github.com/ponylang/rfcs/pull/161
- Pony Issue: https://github.com/ponylang/ponyc/issues/3593

# Summary

This RFC suggests adding functionality inspired by the [maybe](https://github.com/mfelsche/pony-maybe) library to the Pony stdlib via the itertools package. This provides an alternative API to work with optional types, that is union types with `None`: `( T | None)`. Its goal is to facilitate the usage of such optional types for people for which using pattern matching (using `match` or `as` expressions) is not convenient. Such types are very common for mutable fields on a class that need to be initialized but there is no value in the optional type to encode a missing thing. In those cases a union with `None` is initialized to `None` and updated at a later point.

Example:

```pony
use "itertools"

class WithOptionalStuff
  let _stuff: (String | None) = None

  fun update_stuff(new_stuff: String): (String | None) =>
    _stuff = new_stuff

  // without maybe
  fun size_with_match(): USize =>
    match _stuff
    | let s: String => s.size()
    else
      0
    end

  fun size_with_as(): USize =>
    try
      (_stuff as String).size()
    else
      0
    end

  // using maybe and next_or
  fun size_from_iter(): USize =>
    Iter[String].maybe(_stuff).map[USize]({(s) => s.size() }).next_or(0)
```


# Motivation

It is idiomatic in Pony to express optional types as a union of that type and `None`: `(Type | None)`. To get to the actual reference a `match` expression or an `as` expression must be used. Both might not be the most convenient way to deal with optional types. The former, because might be a lot of code to write, the latter because it is partial and requires a surrounding `try` block. Especially people coming from languages like java or scala, that have a class `Option[T]` or `Optional<T>` might find a similar api more appealing.

Handling optional types is a regular question on the Ponylang zulip chat, especially for newcomers, and also because it is so common; And nearly everytime we suggest pattern matching using `match` expressions, `as` expression or using the [maybe](https://github.com/mfelsche/pony-maybe) library.

# Detailed design

The following extensions to the `itertools.Iter[A]` class are proposed to fill this gap:
```pony
class Iter[A] is Iterator[A]
  let _iter: Iterator[A]

  // ...

  new maybe(value: (A | None)) =>
    _iter =
      object is Iterator[A]
        var _value: (A | None) = consume value
        fun has_next(): Bool => _value isnt None
        fun ref next(): A ? => (_value = None) as A
      end

  fun ref next_or(default: A): A =>
    """
    Return the next value, or the given default.

    ## Example

    ```pony
    let x: (U64 | None) = 42
    Iter[U64].maybe(x).next_or(0)
    ```
    `42`
    """
    if has_next() then
      try next()? else default end
    else
      default
    end
```

# How We Teach This

The `next_or` function will be documented similarly to existing functions on `Iter`, as shown above.

# How We Test This

The `maybe` and `next_or` functions will be covered by the unit tests in the `itertools` package.

# Drawbacks

- Maintenance cost of added code

- Feature Name: add-maybe-package-to-stdlib
- Start Date: 2020-04-21
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

This RFC suggests to add the [maybe](https://github.com/mfelsche/pony-maybe) library to the Pony stdlib as its own package. It provides an alternative API to work with optional types, that is union types with `None`: `( T | None)`. Its goal is to facilitate the usage of such optional types for people for which using pattern matching (using `match` or `as` expressions) is not convenient. Such types are very common for mutable fields on a class that need to be initialized but there is no value in the optional type to encode a missing thing. In those cases a union with `None` is initialized to `None` and updated at a later point.

Example:

```pony
use "maybe"

class WithOptionalStuff
  let _stuff: Maybe[String] = None

  fun update_stuff(new_stuff: String): Maybe[String] =>
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

  // using maybe
  fun size_from_iter(): USize =>
    var s: USize = 0
    for stuff in Opt.iter[String](_stuff) do
      s = s + stuff.size()
    end
    s

  fun size_using_map_and_get(): USize =>
    // this would be much less to type if we had generic type inference
    Opt.get[USize](
      Opt.map[String, USize](_stuff, {(s) => s.size() }),
      0
    )
```


# Motivation

It is idiomatic in Pony to express optional types as a union of that type and `None`: `(Type | None)`. To get to the actual reference a `match` expression or an `as` expression must be used. Both might not be the most convenient way to deal with optional types. The former, because might be a lot of code to write, the latter because it is partial and requires a suurrounding `try` block. Especially people coming from languages like java or scala, that have a class `Option[T]` or `Optional<T>` might find a similar api more appealing.

To this end the [maybe](https://github.com/mfelsche/pony-maybe) library should be included into the Pony stdlib as a separate package. It provides an alternative api to the Pny core language instruments for handling optional types. The [maybe](https://github.com/mfelsche/pony-maybe) api allows to use operations like `map`, `flat_map`, `filter`  on optional types in Pony, that are well-known from other functional languages 

Handling optional types is a regular question on the Ponylang zulip chat, especially for newcomers, and also because it is so common; And nearly everytime we suggest pattern matching using `match` expressions, `as` expression or using the [maybe](https://github.com/mfelsche/pony-maybe) library.


# Detailed design

The detailed design of the [maybe](https://github.com/mfelsche/pony-maybe) library can be found in its current github repository:

    https://github.com/mfelsche/pony-maybe

As a package name, i would stick to `maybe`, as the other alternatives that come to mind: `option` or `optional` or `opt` is too close to the existing (though deprecated) stdlib package [options](https://stdlib.ponylang.io/options--index).

## Usage examples

Do something when the optional type is present:

```pony
// without maybe
match opt_thing
| let thing: T =>
  // do something with thing
end

// with maybe
Opt.apply[T](opt_thing, {(thing) => /* do something with thing */ })

// with maybe II
for thing in Opt.iter[T](opt_thing) do
  // do something with thing
end
```

Get the thing out of an optional type and get a default value if it is not:

```pony
// without maybe
match opt_thing
| let thing: T => thing
else
  some_default_thing
end

// with maybe
Opt.get[T](opt_thing, some_default_thing)
```

Chain multiple expression, returning an optional type, together:

```pony
// without maybe
let opt_t2: (T2 | None) = 
  match get_me_some_opt_thing()
  | let thing: T => take_t_return_opt_t2(thing)
  end

// with maybe
let opt_t2: Maybe[T2] = Opt.flat_map[T, T2](
  get_me_some_opt_thing(), {
    (thing) => take_t_return_opt_t2(thing)
  }
)
```


# How We Teach This

The package will receive much more documentation, both for the type `Maybe[T]` itself and also for the `Opt` primitive and its methods. Each will contain one or more usage examples. The package documentation will contain explanations of what optional types are, how to use them and what alternatives this package provides.

# How We Test This

The [maybe](https://github.com/mfelsche/pony-maybe) library contains unit tests that will be moved to the stdlib test suite.

# Drawbacks

* Maintenance cost of added code

# Alternatives

* Leave the library in its own repository, having it harder to find, since we don't have no fully working pony package index yet.

# Unresolved questions

Any better/other naming ideas?

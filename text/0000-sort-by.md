- Feature Name: sort-by
- Start Date: 2020-04-27
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Add a `SortBy` primitive to `collections` package.

# Motivation

The generic parameter of `Sort` requires the implementation of the `Comparable` interface， if the existing type does not implement `Comparable` interface will be helpless, `SortBy` allows any type, it solves this problem by injecting a lambda.

# Detailed design

- `SortBy` has the same interface as `Sort`. 
- `SortBy` uses a `lambda` as the hash evaluation method instead of `interface Comparable`.

For example:

```pony
use "collections"

actor Main
  new create(env:Env) =>
    let array = [ "aa"; "aaa"; "a" ]
    SortBy[String](array, {(x: String): U64 => x.size().u64() })
    for e in array.values() do
      env.out.print(e) // prints "a \n aa \n aaa"
    end
```

# How We Test This

All test cases for `Sort` are also valid for `SortBy`. Its design and implementation are already complete and working.
Source : https://github.com/damon-kwok/pony-shoe/blob/master/sort_by.pony

# Drawbacks

- The user must ensure that the lambda evaluation function is valid.
- Compared to Sort's compile-time check, `SortBy` has a little runtime overhead.


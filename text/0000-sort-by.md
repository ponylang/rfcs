- Feature Name: sort-by
- Start Date: 2020-04-27
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Add a `SortBy` primitive to `collections` package.

# Motivation

- Sort is not beginner friendly，The generic parameter of sort requires the implementation of the A interface.`SortBy` allows any type.
- If the existing type does not implement `Comparable` interface will be helpless. sort solves this problem by injecting a lambda.

# Detailed design

- `SortBy` has the same interface as `Sort`. 
- `SortBy` uses a `lambda` as the hash evaluation method instead of `interface Comparable`.

```pony
use "collections"

actor Main
  new create(env:Env) =>
    let array = [ "aa"; "aaa"; "a" ]
    SortBy(array, {(x: String): USize => x.size() })
    for e in array.values() do
      env.out.print(e) // prints "a \n aa \n aaa"
    end
```

# How We Test This

All test cases for `Sort` are also valid for `SortBy`. Its design and implementation are already complete and working.
Source : https://github.com/damon-kwok/pony-shoe/blob/master/sort_by.pony

# Drawbacks

The user must ensure that the lambda evaluation function is valid.


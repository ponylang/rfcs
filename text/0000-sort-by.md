- Feature Name: sort-by
- Start Date: 2020-04-27
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Add a `SortBy` primitive to `collections` package.

# Motivation

- Sort is not beginner friendly.
- Sort requires the implementation of the `Comparable interface`, if the existing type does not implement this interface will be helpless.

# Detailed design

- `SortBy` has the same interface as `Sort`, but `SortBy` use any type as the key. 
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


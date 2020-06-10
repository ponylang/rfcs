- Feature Name: new-collection-type-without-generic-constraints
- Start Date: 2020-04-27
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Add `SortBy` `AnyMap` and `AnySet` to `collections` package.

# Motivation

`SortBy` primitive like `Sort`, but it use a `lambda` replaced `interface Comparable`. it can use the any type for Key.
`AnyMap` like `Map`, but it use a `lambda` for hash calculation. it can use the any type for Key.
`AnySet` like `Set`, but it use a `lambda` for hash calculation. it can use the any type for Key.

# Detailed design

Removed the need for dependency on the `Comparable`, `Hashable` and `Equatable` interfaces, and added a Lambda parameter to accomplish the same thing.

# How We Teach This

```pony
use "collections"

actor Main
  new create(env:Env) =>
    let array = [ "aa"; "aaa"; "a" ]
    SortBy(array, {(x: String):USize => x.size()})
    for e in array.values() do
      env.out.print(e) // prints "a \n aa \n aaa"
    end

    let map = AnyMap[U8, String]({(key: U8): USize => key.usize_unsafe()})
    map(1)="I"
    map(2)="love"
    map(3)="Pony"

    let map2 = AnyMap[U8, String](object is HashFunction[U8]
      fun hash(x: U8): USize => ...
      fun eq(x: U8, y: U8): Bool => ...
    end)
	
	let set = Set[CustomType]
	set.size()
````

# How We Test This

All test cases for `Sort` are also valid for `SortBy`. Its design and implementation are already complete and working.
SortBy : https://github.com/damon-kwok/pony-shoe/blob/master/sort_by.pony
AnyMap : https://github.com/damon-kwok/pony-shoe/blob/master/any_map.pony
AnySet : https://github.com/damon-kwok/pony-shoe/blob/master/any_set.pony

# Drawbacks

The users must ensure that the lambda evaluation function is valid, and ensure the correctness of hash calculation.

# Alternatives

It can be used as a third-party library, provided to users through the package manager.

# Unresolved questions

None.

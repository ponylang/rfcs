- Feature Name: change_string_join_to_take_iterable
- Start Date: 2017/07/25
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Change String.join(ReadSeq[Stringable]) to String.join(Iterator[String]).

# Motivation

The Iterator interface placed fewer requirements on the implementation when compared to ReadSeq and it is trivial to convert from a ReadSeq to an Iterator, however it is more difficult and has a higher cost to convert in the other direction.  The function does not require any more than Iterator interface.  There are a number of existing parts of the stdlib that allow useful functions to be applied to Iterators.  Being able to pass the result straight in to the join function simplifes producing string output of those results.

One specific case I ran into was converting an array non-stringable values (e.g. Tuple) into a string:
```
let a: Array[(I64, I64)] = [(1, 2); (0, 4); (19, 3)]
let fn = { (x: (I64, I64)) : String =>  "(" + x._1.string() + "," + x._2.string() + ")" }
let s = ",".join(MapFn[(I64, I64), String](a.values(), fn))
```

# Detailed design

This is relatively straight forward change.  The signature of the join method changes to: `fun join(data: Iterator[Stringable]): String iso^`.  The call to `data.values()` is replaced to using the data value directly.  This will break all current uses of the join method.  They would need to change to calling `.values()` before passing the argument to the join method.

# How We Teach This

There are no new concepts to teach, however it would be necessary to inform uses that the change would break existing code.  All calls like `",".join(input)` would need to change to `",".join(input.values())`.

# How We Test This

The existing unit tests should be sufficient, with the appropriate compiler error fixes.  The results of the function should remain the same.

# Drawbacks

Breaks existing code.

# Alternatives

1. Use a case function that supports both ReadSeq and Iterator interfaces.  This will still break existing code as the return type change to (String | None)
1. Add a second function e.g. `joinWithIterator` that would not break the existing code.  The existing method could be changed to used the new one.

# Unresolved questions

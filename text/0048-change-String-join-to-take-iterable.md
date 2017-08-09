- Feature Name: change-string-join-to-take-iterable
- Start Date: 2017/07/25
- RFC PR: https://github.com/ponylang/rfcs/pull/98
- Pony Issue: https://github.com/ponylang/ponyc/issues/2148

# Summary

Change String.join(ReadSeq[Stringable]) to String.join(Iterator[String]).

# Motivation

The Iterator interface places fewer requirements on the implementation when compared to ReadSeq.  The ReadSeq requires that your implementation have random access (apply(USize): T), have a known size (size(): USize) and support sequential (ordered) access by returning an Iterator from the values() function. Where as the Iterator only requires that the implementation have sequential access, so is a subset of the functionality if ReadSeq. There are a number of cases where supporting an Iterator interface rather than ReadSeq would be desirable. Supporting a database cursor or a stream from a network service are two that come immediately to mind.

The other case that crops up is compatibility with other parts of the pony stdlib. The itertools package which provides a number of useful functions over unbounded streams of data, similar java streams library. The specific case I was looking at taking a stream of data, mapping a transformation over it, then joining the result. Itertools was the only part of the library that supported that sort of functionality, but didn't provide a join or reduce function. I found the join function on String, which required that the call supply a ReadSeq, but internally only ever needs in Iterator. It seems a simple and obvious change to make the join function take an Iterator making it a more useful function. It is trivial to convert from a ReadSeq to an Iterator, however it is more difficult and has a higher cost to convert in the other direction.

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

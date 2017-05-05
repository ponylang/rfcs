- Feature Name: Optional Return
- Start Date: 2016-06-08
- RFC PR:
- Pony Issue:

# Summary

The 'return' keyword is only allowed if it is not the last expression of a function. This proposal is about allowing it to end a function, without removing the support for the returned value to be the last expression.

# Motivation

Not having to put the 'return' keyword on purely functional function like traditional C-like language does bring clarity to the code. But for longer piece of code, for functions which unfortunately cannot be displayed entirely on the screen, its a little harder to see quickly where the function is actually ending and returning the value. It is especially true since Pony doesn't have some braces to mark the end of a function.

Very often code is syntactically colored, in the context of our favorite editors, but also online. So the 'return' keyword would helps to quickly know where the function ends and return a value.

# Detailed design

The change in the language would be about allowing the 'return' keyword to end a function.

# How We Teach This

By default, since shorter functions makes a better code design, the documentation should still continue to use examples where the last expression is the returned value without the 'return' keyword.

This feature would only document once, explaining that it might be useful for longer functions. A good place for a short paragraph would be in the [methods](http://tutorial.ponylang.org/expressions/methods.html) section of the tutorial.

# Drawbacks

It may be seen as a incitation to write long procedural code rather than simple little functions. But if it is not advertised in the doc, if the example and the builtin package are not using that last return, the culture should not be affected.

# Alternatives

None

# Unresolved questions

None

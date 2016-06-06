- Feature Name: Try, catch, else, finally
- Start Date: 2016-06-06
- RFC PR:
- Pony Issue:

# Summary

This RFC advocates for a rename of "else" to "catch", "then" to
"finally", and introduces an "else" clause which is reached if no
error was raised.

# Motivation

The "catch" and "finally" terms are common in programming
languages.

Using "catch" frees "else" up for a different purpose which is the
meaning from the Python language where the "else" clause exists to
guard precisely the code that we can expect to sometimes raise an
error and not the code that comes after.

The term "then" is commonly used in promise terminology to mean "on
success". This is why this RFC recommends "finally" instead.


# Detailed design

The design of the new "else" clause is straight-forward. After the
"try" clause finishes we set a flag and outside the "try" block this
flag is tested to see if we should enter the "else" clause.


# How We Teach This

The documentation will need to be updated.


# Drawbacks

The main drawback is that we already have lots of code that uses the
current syntax.

That said, we can improve the code in many places using the new "else"
clause. This will result in better code with less bugs.


# Alternatives

Currently none are proposed.


# Unresolved questions

The reuse of "else" leaves a question of how to transition code safely
to the new syntax.

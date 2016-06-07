- Feature Name: Try, then, else, finally
- Start Date: 2016-06-06
- RFC PR:
- Pony Issue: #291

# Summary

This RFC advocates for a rename of "then" to "finally", and introduces
a "then" clause which can be placed immediately after the "try" block
to program the case where no error was raised. Local variables
introduced in the "try" block can be used here.


# Motivation

It's important to "try" only code that can actually fail, for the
reason that it avoids making a false assumption, but also to
communicate clearly to the reader what lines of code we're "trying".

In other Pony syntax "then" means if-this-then and here it is a good
candidate try-this-and-then. In addition, "then" is commonly used in
promises to mean "on success". This could lead to some confusion (note
that "then" is a reserved keyword already and cannot be used a method
name).

Instead, "finally" is used in mainstream languages such as Java and
Python and communicates its semantic quite clearly.


# Detailed design

The "then" clause is syntax sugar that could expand to:
```pony
let success = \
try
   something()
   true
else
   handle_error()
   false
end

if success then
   then_block()
end
```

Note that in an actual implementation, a "try" block can be used as an
expression which changes the above expansion a little.


# How We Teach This

The documentation will need to be updated.


# Drawbacks

The main drawback is that code that uses "then" today will need to be
updated to use "finally" instead.

Meanwhile, we can improve the code in many places using the new "then"
clause. This will result in better code with less bugs.

Note that the compiler will be able to detect code that uses the old
construct and vice versa.


# Alternatives

The unsugared syntax exhibited in the detailed design notes can be
thought of as an alternative. It has the drawback that a "try" block
needs to be named (in the sense that a "let" symbol is used) and
naming is hard. This leads to common names such as "success" except
this obviously can't be reused in the same scope.


# Unresolved questions

Currently none.

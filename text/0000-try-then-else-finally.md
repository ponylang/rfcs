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

The most efficient and simplest implementation is to simply have the
compiler generate the LLVM IR as if the "then" block was tacked on to
the end of the try block, and to make sure that the Pony compiler
enforces that the then block cannot raise an error.


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

The "then" clause could be expanded to something like:
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

Due to compiler limitations in the tracking of ``consume`` branches
this expansion is not exactly equivalent to the LLVM IR-based
implementation.

It also has the drawback that a "try" block needs to be named (in the
sense that a "let" symbol is used) and naming is hard. This leads to
common names such as "success" except this obviously can't be reused
in the same scope.


# Unresolved questions

Currently none.

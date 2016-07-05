- Feature Name: http-status
- Start Date: 2016-07-02
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Adding a set of primitives to represent the HTTP Status Codes would provide convenience to the programmer and increase the readability of their code. The status codes used will be those defined in RFC 2616.

# Motivation

This addition would provide a clean and safe way to deal with HTTP status codes.

# Detailed design

Each HTTP status code will be represented by a primitive which implements the Status trait. The trait will have an apply() function that returns the U16 status code and a text() function that returns the corresponding status text.

```pony
trait val Status
  fun apply(): U16
  fun text(): String

primitive StatusContinue is Status
  fun apply(): U16 => 100
  fun text(): String => "Continue"

primitive StatusSwitchingProtocols is Status
  fun apply(): U16 => 101
  fun text(): String => "Switching Protocols"

primitive StatusOK is Status
  fun apply(): U16 => 200
  fun text(): String => "OK"

primitive StatusCreated is Status
  fun apply(): U16 => 201
  fun text(): String => "Created"

...
```

# How We Teach This

The primitives are self explanatory and will be available in the net/http package of the standard library.

# Drawbacks

None

# Alternatives

None

# Unresolved questions

None

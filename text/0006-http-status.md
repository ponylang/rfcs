- Feature Name: http-status
- Start Date: 2016-07-02
- RFC PR: https://github.com/ponylang/rfcs/pull/18
- Pony Issue: https://github.com/ponylang/ponyc/issues/1041

# Summary

Adding a set of primitives to represent the HTTP Status Codes would provide convenience to the programmer and increase the readability of their code. The status codes used will be those defined in RFC 2616.

# Motivation

This addition would provide a clean and safe way to deal with HTTP status codes.

# Detailed design

Each HTTP status code will be represented by a primitive which implements the Status trait. The trait will have an apply() function that returns the U16 status code and a string() function that returns the corresponding status text.

```pony
trait val Status
  fun apply(): U16
  fun string(): String

primitive StatusContinue is Status
  fun apply(): U16 => 100
  fun string(): String => "100 Continue"

primitive StatusSwitchingProtocols is Status
  fun apply(): U16 => 101
  fun string(): String => "101 Switching Protocols"

primitive StatusOK is Status
  fun apply(): U16 => 200
  fun string(): String => "200 OK"

primitive StatusCreated is Status
  fun apply(): U16 => 201
  fun string(): String => "201 Created"

...
```

The signature of the response constructor for Payload would also be changed to the following:
```pony
new iso response(
  status': Status = StatusOK,
  handler': (ResponseHandler val | None val) = reference)
: Payload iso^
```

# How We Teach This

The primitives are self explanatory and will be available in the net/http package of the standard library.

# Drawbacks

None

# Alternatives

None

# Unresolved questions

None

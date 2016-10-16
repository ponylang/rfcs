- Feature Name: Capability Based Access Modifiers
- Start Date: 16-10-2016
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

While capabilities is a language feature, Pony does not use this for the benefit of access modifiers.

# Motivation

Capabilities based access modifiers will support more fine grain protection including:

 - fine grain access modifiers
 - type state / phantom types

# Detailed design

Though current access modifier scheme in Pony is very simple it is best that it 
leverages capabilities and typing which is strong suit in Pony. This would better 
fit the conceptual framework of the language better.

All access should be public to stat with unless restricted. The potential type of 
restrictions are:

- pvt[this.type] - any instance of the same type
- pvt[this.type :>] / pvt[this.type <:] - any instance of the this type or a subtype
- pvt[this.type <:] / pvt[this.type :>] - any instance of the this type or a supertype
- pvt[this] - only this instance
- pvt[this.package.* :>] - only this package and types deriving from other types in this package
- pvt[P.A] - only this type A in package P
- pvt[A, B, C] - only an instance of A, B, C; generic type parameters A, B, C or package A, B, C
- pvt[A #f, B #g] - only an in f and g of A, B
- pvt[(A :>) #f, (B <:) #g] - only an in f and g in a subtype of A and a supertype of B

# How We Teach This

This is using capabilities as means to 

# How We Test This

You should be able to specify:

- Type state / phantom type 
- Friend functions (class / actor / package specific access)
- Different protection levels

# Drawbacks

* Breaks existing code
* Maintenance cost of added code
* More complicated than what is implemented

# Alternatives

Continue with current implementation.

# Unresolved questions

None

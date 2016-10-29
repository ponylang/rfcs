- Feature Name: Capability Based Access Modifiers
- Start Date: 16-10-2016
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

While capabilities is a language feature, Pony does not use this for the benefit 
of access modifiers.

# Motivation

Capabilities based access modifiers will support more fine grain protection including:

 - fine grain access modifiers
 - type state / phantom types
 
 The access privileges will be captured by the type system hence many context aware 
 access capabilities like you can only close a file which is open.
 

# Detailed design

Though current access modifier scheme in Pony is very simple it is best that it 
beverages capabilities and typing which is strong suit in Pony. This would better 
fit the conceptual framework of the language better.

All access should be public to start with unless restricted. The potential type of 
restrictions are:

- `pvt[this.type]` - any instance of the same type
- `pvt[this.type :>]` / `pvt[this.type <:]` - any instance of the this type or a subtype
- `pvt[this.type <:]` / `pvt[this.type :>]` - any instance of the this type or a supertype
- `pvt[this]` - only this instance
- `pvt[this.package.* :>]` - only this package and types deriving from other types in this package
- `pvt[P.A]` - only this type A in package P
- `pvt[A, B, C]` - only an instance of A, B, C; generic type parameters A, B, C or package A, B, C
- `pvt[A #f, B #g]` - only an in f and g of type A, B
- `pvt[(A :>) #f, (B <:) #g]` - only an in f and g in a subtype of A and a supertype of B
- `pvt[A | A =:= B]` - private to A when A is B

More concrete examples

## Private to Instance

```
class Foo
  var x: U32 pvt[this]
```

## Private to Package A

```
class Foo
  var x: U32 pvt[A]
```

## Private to Class

```
class Foo
  var x: U32 pvt[class]
```

## Private To Instance Given Type A Type (evidence)

```
interface File
  fun close(): CloseFile pvt[this | this.type =:= OpenFile]
```

# How We Teach This

This can be taught more in-line with the capabilities and there is some similarity. Also a chapter or 
section after capabilities might might be the best way to teach this. Some of the potential test cases:

- restrict access to instance methods and behaviours within the class or actor
- restrict access to instance or subtype methods and behaviours within the class or actor
- restrict access to class or actor type
- restrict access to class or actor subtype
- restrict access to package
- restrict access to package for classes or actors of a given instance
- restrict access to package for classes or actors of a given type
- restrict access to based on evidence provided


# How We Test This

You should be able to specify different protection levels than what is possible now. So testing 
should be based on the combination for protection the possible protection levels discussed above.

# Drawbacks

* Breaks existing code
* Maintenance cost of added code
* More complicated than what is implemented

# Alternatives

Continue with current implementation or drop access modifies altogether.

# Unresolved questions

Typing in the presence of this scheme of access modifies will need to be resolved. In addition 
other areas of the language which might be effected needs to be identified.
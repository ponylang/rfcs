- Feature Name: STD_Set_Impl
- Start Date: 2018-10-16
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

An implementation of a Set as it pertains to Set Thoery.

# Motivation

Sets are primitives of many fields in mathematics. Sets are integral to Graph Theory, Number Theory, Information Theory, Probability and more. As many fields of mathematics really on Sets as a primitive, it is necessary to include a standard implementation, such that libraries building on this work can interact easily.

# Detailed design

Defintion of a Set:  
```
A `Set` is a collection of definite distinct objects called Elements (of the set).
```
Sets can be denoted in the following manner:
```
let S = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
```
In the above set, the first item, `1`, is said to be an `Element` of the set, `S`. 
As previously mentioned in our definition, elements must be definite and distinct. Therefore, elements cannot exist several times within a set. 
```
let S = { 1, 2, 3 } // valid set
let T = { 1, 1, 3 } // invalid set
```


Equality and Comparability:

note: In logic, `IFF` denotes "if and only if", <=>. It will be used in the following section.

Definition of Equality:
```
Two sets are equal `iff` both sets contain the same elements.
```
Equality is therefore reflexive, symmetric, and transitive. Equality of sets is denoted in the following manner:
```
S = T
```
where `S` and `T` are both sets.
If the above equality holds true, then the following is also true:
```
S = S // reflexive

if   S = T 
then T = S   // symmetric

if   S = T
and  T = V
then S = V  // transitive
```


# How We Teach This

What names and terminology work best for these concepts and why? How is this idea best presented? As a continuation of existing Pony patterns, or as a wholly new one?

Would the acceptance of this proposal mean the Pony guides must be re-organized or altered? Does it change how Pony is taught to new users at any level?

How should this feature be introduced and taught to existing Pony users?

# How We Test This

How do we assure that the initial implementation works? How do we assure going forward that the new functionality works after people make changes? Do we need unit tests? Something more sophisticated? What's the scope of testing? Does this change impact the testing of other parts of Pony? Is our standard CI coverage sufficient to test this change? Is manual intervention required?

In general this section should be able to serve as acceptance criteria for any implementation of the RFC.

# Drawbacks

Why should we *not* do this? Things you might want to note:

* Breaks existing code
* Introduces instability into the compiler and or runtime which will result in bugs we are going to spend time tracking down
* Maintenance cost of added code

# Alternatives

What other designs have been considered? What is the impact of not doing this?
None is not an acceptable answer. There is always to option of not implementing the RFC.

# Unresolved questions

What parts of the design are still TBD?

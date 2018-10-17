- Feature Name: STD_Set_Impl
- Start Date: 2018-10-16
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

An implementation of a Set as it pertains to Set Thoery.

# Motivation

Sets are primitives of many fields in mathematics. Sets are integral to Graph Theory, Number Theory, Information Theory, Probability and more. As many fields of mathematics really on Sets as a primitive, it is necessary to include a standard implementation, such that libraries building on this work can interact easily.

# Detailed design

## Defintion of a Set
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


## Equality, Equivalence, and Comparability

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

Set Cardinality:
The number of elements of a set is called the `cardinality` of the set.
```
let S = { 1, 2, 3 }
let T = { 1, 2, 3, 4, 5 }
let V = { 4, 5, 6, 7, 8, 9, 10 }
```
The `cardinality` of `S` = 3, `T` = 5, and `V` = 7.

Set Equivalence:
Two sets are equivalent `iff` elements of either set can correspond to exactly one element of the other set. Therefore, if the two sets have equal cardinalities, then the sets are equivelant, and any two sets which are equivalent will also have equal cardinalities.

```
let S = { 1, 2, 3 }
let T = { A, B, C }
```
Sets `S` and `T` are said to be equivalent because elements of `S` can be mapped to exactly one element of `T`, and the inverse is also true. However, `S` and `T` are not equal sets.

Subsets:
```
A set, S, is a subset of set T `iff` every element of S is also an element of T
```
A set is said to be a `Proper Subset` if it is simultaneously a subset and not equal to another set.
```
let S = { 1, 2, 3 }
let T = { 1, 2, 3 }
let V = { 1, 2, 3, 4 }
```
Set `S` is equal to set `T`.  
Set `S` is a subset of set `T`.  
Set `S` is a subset of set `V`.  
Set `S` is a proper subset of `V`.  
Set `S` is not a proper subset of `T`.  

Subsets that are not proper subsets are said to be improper.

Supersets:
```
A set, T, is a superset of S `iff` every element of S is also an element of T
```
Supersets have similar proper/improper labels. Using the same example as above, the following is true:  
Set `T` is a superset of set `S`.  
Set `V` is a superset of set `S`.  
Set `V` is a proper superset of set `S`.  
Set `T` is an improper superset of set `S`.  

We should also agree, based on the previous principles, (1) that all sets are improper subsets (and supersets) of themselves, and (2) that the empty set is a subset of every set.

The Empty Set:
```
the empty set = { }
```

Complementary Sets:

Given that a set `S` is a proper subset of another set, `T`, then there exists a third set, `V`, which contains all elements of `T` which are not contained in `S`. This set, `V`, is said to be the `complementary` set of `S` `over` `T`.
```
let S = { 1, 2, 3 }
let T = { 1, 2, 3, 4, 5, 6 }
```
The complementary set of `S` `over` `T`, in the above example is as follows:
```
V = { 4, 5, 6 }
```
This can be expressed in the following way:
```
V = T - S
```
a note on subsets: for every set of N elements, there are exactly 2^N subsets.

Unions:
Given two sets, the `union` of the sets is a set which contains all elements of either set.

```
let S = { 1, 2, 3 }
let T = { 4, 5, 6 }
```
The `union` of set `S` and `T` in the above example is as follows:
```
V = { 1, 2, 3, 4, 5, 6 }
```
As we have previously mentioned in our above definition of a set, elements of a set must be distinct. Therefore, a union of two sets, of which at least one is a subset of the other, will contain only one instance of each element. This property is demonstrated below:
```
let S = { 1, 2, 3, 6 }
let T = { 1, 2, 3, 4, 5 }
```
The `union` of `S` and `T` is as follows:
```
V = { 1, 2, 3, 4, 5, 6 }
```

Intersections:
Given two sets, the `intersection` of the sets is a set which contains all elements which are elements of both sets.

```
let S = { 1, 2, 3, 4, 5 }
let T = { 3, 4, 5, 6, 7 }
```
The `intersection` of `S` and `T` is as follows:
```
V = { 3, 4, 5 }
```
In the case that two sets share no common elements, then the intersection of the two sets is the empty set, and the sets are said to be `disjoint`.

With these formal definitions, we have sufficient information to begin describing the implementation.

## Data Structures

Set:
```pony
  class Set
    """
     Docs
    """
    create // todo
```

Empty Set:
```
  static Set Empty = Set{ } 
```
## Methods

Equality:
```
  Bool is_equal(set: Set)
```

Cardinality:
```
  uint cardinality()
```

Equivelance:
```
  Bool is_equivalent(set: Set)
```

Subsets:
```
  Bool is_subset(set: Set)
  Bool is_proper_subset(set: Set)
```

Supersets: 
```
  Bool is_superset(set: Set)
  Bool is_proper_superset(set: Set)
```

Empty:
```
  Bool is_empty_set()
```

Complementary:
```
  Set get_complementary_set(set: Set)
  Bool is_complementary_set(set: Set, complement: Set)
```

Unions:
```
  Set get_union(set: Set)
  Bool is_union(set: Set, union: Set)
```

Intersections:
```
  Set get_intersection(set: Set)
  Bool is_intersection(set: Set, intersect: Set)
  Bool are_disjoint(set: Set)
```

Operators:
```
  Set A == Set B => A.is_equal(B)
  Set A != Set B => !A.is_equal(B)
  Set A >= Set B => A.is_superset(B)
  Set A >  Set B => A.is_proper_superset(B)
  Set A <= Set B => A.is_subset(B)
  Set A <  Set B => A.is_proper_subset(B)
  Set A |  Set B => A.get_union(B)
  Set A &  Set B => A.get_intersection(B)
```


# How We Teach This

The best terminology for this library would be to stick with pure set theory terminology. There likely won't be much to teach, as anyone who will be using this library will have some familiarity with set theory, and it's terminology. Set Theorists who will be the target consumers of this library will feel most comfortable with their usual terms.

# How We Test This
 Unit tests will be created.

# Drawbacks
Adding this to the standard library will have some maintainece cost associated. 

# Alternatives
Some alternatives could be other naming conventions. Some Set Theory terminology can seem quite nuanced to novices, especially with terms like "Equal" and "Equivalent" having very different meanings. Another alternative would be completely leaving this structures and methods out of the standard library and using it as a free-standing thrid-party library.

# Unresolved questions
What is the most idiomatic way to structure this class?
Can operators be overloaded?

- Feature Name: Graph Implementation
- Start Date: 2018-10-16
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Create an implementation of a graph. A Graph, in Graph Theory, is defined as an object containing two sets, a vertex set and an edge set. This RFC currently only contains the data structures. Algorithms will be added once a structure is formalised.

# Motivation

Graphs are useful to a whole host of interests in mathematics and have many applications. Graphs could be useful in implementing other algorithms and data structures, and could be useful in representing networks.
Since graphs have a basis in many fields, it makes sense to have a standard implementation so that future third-party libraries can't easily interact with eachother. 

# Detailed design

Three classes will need to exist:
 - Graph
 - Vertex
 - Edge 

 As previously mentioned, a Graph is defined as an object containing two set: A Vertex set, and an Edge set. 
 Thus, we can define a Graph in the following pseudo code:
  ```
    class Graph {
      Set<Vertex> Vertices
      Set<Edge> Edges
    }
    
  ```
  *note: Set is used in the Set theory sense, meaning a collection of objects, not a HashSet.
  
  Vertex an entity in Graph Theory. It can hold a value, and be described as the following pseudo code:
  ```
    class Vertex<T> {
      T Item
    }
  ```

  An Edge is a relationship in Graph Theory. It connects two vertices. It can be defined in the following pseudo code:
  ```
    class Edge {
      Vertex Source
      Vertex Destination
    }
  ```
  An Edge can be undirected or directed, and can be weighted or unweighted. 

# How We Teach This

In Graph Theory, the entity of the graph is known as a Vertex. LinkedLists, Trees, Tries, etc are all examples of a graph. In these domain examples from computer science, the entities are often known as Nodes. `Node` could be an alternative name to Vertex.
This feature add only to the math standard library. It does not add to the learning curve of Pony, and does add any increased complexity to the language or compiler. It's simply a library that can be used at the descretion of the developer.

# How We Test This

This RFC currently only defines the datastructures. There is not much logic contained within it's definition. Therefore, an implementation will meet acceptance criteria when it meets a formal definition of a graph. Algorithms will be added after the structure is formalized, and will have a much more complete test suite.

# Drawbacks

This code expands the surface of the standard library. As such, there will be a maintaince cost associated with this feature.

# Alternatives

There could be a third-party library, not included in the standard library. This implementation follows the Graph theory definition, but another implementation might be more similar to a linkedlist. Instead of maintaining a collection of vertices and edges, each vertex could maintain a collection of outbound edges. I think such an implementation could coexist and allow for simple methods for building one from the other. 

```
 class Node<T> {
  T Item
  List<Node> Edges
 }
```


# Unresolved questions

What conventions should be used.

# Related
 Set Implementation
 Matrix Implementation
 Graph Algorithms


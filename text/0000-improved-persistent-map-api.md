- Feature Name: improved-persistent-map-api
- Start Date: 2017-03-09
- RFC PR: 
- Pony Issue: 

# Summary

This RFC proposes improvements to the current persistent map API.

# Motivation

The overall goal of this RFC is to make the persistent map API more consistent with that of the mutable HashMap in the collections package.

# Detailed design

The Maps primitive will be removed and its functionality will be replaced by the following:

- Maps.empty will be replaced with a create constructor on the Map class that takes no arguments and returns a an empty Map with the val reference capability.
- Maps.from will be replaced with a concat method on the Map class with the following signature:
```pony
fun val concat(iter: Iterator[(val->K, val->V)]): Map[K, V]
	"""
    Add the K, V pairs from the given iterator to the map.
    """
```
- The Map.update method will become non-partial since the invariants of the algorithm prevent the possible errors from array operations on entries of each node of the map.

# How We Teach This

The class documentation for the persistent map will be updated to reflect these changes.

# How We Test This

The concat method of the persistent map will require a unit test to verify that it works as intended.

# Drawbacks

Existing code that uses the persistent map will break.

# Unresolved questions

None.

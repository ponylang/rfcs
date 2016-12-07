- Feature Name: nuke-return-this
- Start Date: 2016-11-15
- RFC PR:
- Pony Issue:

# Summary

Remove the "return this" idiom used for chaining in some APIs of the standard library in favor of the new caller-side chaining feature.

# Motivation

With the recent implementation of caller-side method chaining, the "return this" idiom has become useless. It is also harmful to some compiler optimisations because it impedes precise alias analysis.

# Detailed design

Every method that currently uses "return this" for chaining will now either return `None` or return some useful result.

Only public methods are included here. Private methods will be updated based on their usage in the internal API.

- `builtin.Seq`
  - `reserve`: will return `None`
  - `clear`: will return `None`
  - `push`: will return `None`
  - `unshift`: will return `None`
  - `append`: will return `None`
  - `concat`: will return `None`
  - `truncate`: will return `None`
- `builtin.Array`
  - `reserve`: will return `None`
  - `compact`: will return `None`
  - `undefined`: will return `None`
  - `insert`: will return `None`
  - `truncate`: will return `None`
  - `trim_in_place`: will return `None`
  - `copy_to`: will return `None`
  - `remove`: will return `None`
  - `clear`: will return `None`
  - `push`: will return `None`
  - `unshift`: will return `None`
  - `append`: will return `None`
  - `concat`: will return `None`
  - `reverse_in_place`: will return `None`
- `builtin.String`
  - `reserve`: will return `None`
  - `compact`: will return `None`
  - `recalc`: will return `None`
  - `truncate`: will return `None`
  - `trim_in_place`: will return `None`
  - `delete`: will return `None` (this method and `Array.delete` are inconsistent, `String.delete` does the same thing as `Array.remove`, and `String.remove` does something specific to `String`. A separate RFC to clarify that would be good)
  - `lower_in_place`: will return `None`
  - `upper_in_place`: will return `None`
  - `reverse_in_place`: will return `None`
  - `push`: will return `None`
  - `unshift`: will return `None`
  - `append`: will return `None`
  - `concat`: will return `None`
  - `clear`: will return `None`
  - `insert_in_place`: will return `None` (`String.insert` and `Array.insert` are inconsistent. `String.insert_in_place` does the same thing as `Array.insert`)
  - `insert_byte`: will return `None`
  - `cut_in_place`: will return `None`
  - `replace`: will return the number of occurrences replaced
  - `strip`: will return `None`
  - `lstrip`: will return `None`
  - `rstrip`: will return `None`
- `buffered.Reader`
  - `clear`: will return `None`
  - `append`: will return `None`
  - `skip`: will return `None`
- `buffered.Writer`
  - `reserve`: will return `None`
  - `reserve_chunks`: will return `None`
  - number write functions (e.g. `u16_le`): will all return `None`
  - `write`: will return `None`
  - `writev`: will return `None`
- `capsicum.CapRights0`
  - `set`: will return `None`
  - `unset`: will return `None`
- `collections.Flag`
  - `all`: will return `None`
  - `clear`: will return `None`
  - `set`: will return `None`
  - `unset`: will return `None`
  - `flip`: will return `None`
  - `union`: will return `None`
  - `intersect`: will return `None`
  - `difference`: will return `None`
  - `remove`: will return `None`
- `collections.ListNode`
  - `prepend`: will return whether the node was already in a `List`
  - `append`: will return whether the node was already in a `List`
  - `remove`: will return `None`
- `collections.List`
  - `reserve`: will return `None`
  - `remove`: will return the removed element (the method is inconsistent with `Array.remove`)
  - `clear`: will return `None`
  - `prepend_node`: will return `None`
  - `append_node`: will return `None`
  - `prepend_list`: will return `None`
  - `append_list`: will return `None`
  - `push`: will return `None`
  - `unshift`: will return `None`
  - `append`: will return `None`
  - `concat`: will return `None`
  - `truncate`: will return `None`
- `collections.Map`
  - `concat`: will return `None`
  - `compact`: will return `None`
  - `clear`: will return `None`
- `collections.RingBuffer`
  - `push`: will return whether the collection was full
  - `clear`: will return `None`
- `collections.Set`
  - `clear`: will return `None`
  - `set`: will return `None`
  - `unset`: will return `None`
  - `union`: will return `None`
  - `intersect`: will return `None`
  - `difference`: will return `None`
  - `remove`: will return `None`
- `files.FileMode`
  - `exec`: will return `None`
  - `shared`: will return `None`
  - `group`: will return `None`
  - `private`: will return `None`
- `files.File`
  - `seek_end`: will return `None`
  - `seek`: will return `None`
  - `flush`: will return `None`
  - `sync`: will return `None`
- `time.Date`
  - `normal`: will return `None`
- `net.http.Payload`
  - `update`: will return the old value
  - `add_chunk`: will return `None`
- `net.ssl.SSLContext`
  - `set_cert`: will return `None`
  - `set_authority`: will return `None`
  - `set_ciphers`: will return `None`
  - `set_client_verify`: will return `None`
  - `set_server_verify`: will return `None`
  - `set_verify_depth`: will return `None`
  - `allow_tls_v1`: will return `None`
  - `allow_tls_v1_1`: will return `None`
  - `allow_tls_v1_2`: will return `None`

# How We Teach This

The API changes will be reflected in the documentation.

# Drawbacks

These are breaking changes.

# Unresolved questions

None.

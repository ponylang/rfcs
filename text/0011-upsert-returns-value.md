- Feature Name: upsert-returns-value
- Start Date: YYYY-08-19
- RFC PR: https://github.com/ponylang/rfcs/pull/27
- Pony Issue: https://github.com/ponylang/ponyc/issues/1185

# Summary

Currently, Map.upsert returns `this` to allow for chaining. This RFC would switch upsert to returning the new value stored for the given key.

# Motivation

Chaining is a nice convenience but in the end, serves no practical purpose beyond programmer ergonomics. Returning the new value from upsert saves another call to get that value (which in my experience using upsert, is a thing you commonly want to do). 

# Detailed design

Here is the new upsert method body:

```pony
    (let i, let found) = _search(key)

    try
      if found then
        (let pkey, let pvalue) = (_array(i) = _MapEmpty) as (K^, V^)
        _array(i) = (consume pkey, f(consume pvalue, consume value))
      else
        let key' = key
        _array(i) = (consume key, consume value)
        _size = _size + 1

        if (_size * 4) > (_array.size() * 3) then
          _resize(_array.size() * 2)
          return this(key')
        end
      end

      return _array(i) as (_, V)
    else
      error
    end
```

# How We Teach This

Update the docstring for the method to indicate the change.

# Drawbacks

There's a loss of programmer ergonomics in having to do:

```pony
map.upsert(x,y)
map.upsert(z,a)
```

instead of:

```pony
map.upsert(x,y).upsert(z,a)
```

However, when the [chaining RFC](https://github.com/ponylang/rfcs/pull/4) gets accepted and implemented (something everyone on core is quite excited for), this will be a non issue.

# Alternatives

None. This is based on code we currently have running at Sendence.

# Unresolved questions

None. We have a working implementation with tests at Sendence ready to go if this is accepted without modification. Otherwise, there would need to be changes, but I feel pretty good about this.



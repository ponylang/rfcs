- Feature Name: Separate `FilePath` constructor from `AmbientAuth`
- Start Date: 2021-07-02
- RFC PR:
- Pony Issue:

# Summary

It should be without error to constructor a `FilePath` when `AmbientAuth` is provided. The current single constructor uses a union of `(FilePath | AmbientAuth)` to limit capabilities and access for the newly created `FilePath`. Insufficient capabilities or access allows the first half of this union, `FilePath`, to fail, however the latter half `AmbientAuth` can never fail.

# Motivation

Beyond making using `FilePath` more convenient, this change will allow use cases where a path is guaranteed such as constructing a path to the root directory. Currently, all `FilePath` must be constructed within a try-else block. Importantly, `FilePath` does not guarantee its operations will succeed, however a `FilePath` is merely a combination of some directory path and capabilities. No changes to __using__ a `FilePath` are intended by this change.

# Detailed design

The suggested change is to split the implementation in two around the current match statement with `create` using `AmbientAuth` and a new constructor called `from` using an existing `FilePath`.

Current constructor (documentation excluded):

```pony
  new val create(
    base: (FilePath | AmbientAuth),
    path': String,
    caps': FileCaps val = recover val FileCaps .> all() end)
    ?
  =>
    caps.union(caps')

    path = match base
      | let b: FilePath =>
        if not b.caps(FileLookup) then
          error
        end

        let tmp_path = Path.join(b.path, path')
        caps.intersect(b.caps)

        if not tmp_path.at(b.path, 0) then
          error
        end
        tmp_path
      | let b: AmbientAuth =>
        Path.abs(path')
      end
```

Will become:

```pony
  new val create(
    base: AmbientAuth,
    path': String,
    caps': FileCaps val = recover val FileCaps .> all() end)
  =>
    caps.union(caps')

    path = Path.abs(path')
```

and

```pony
  new val from(
    base: FilePath,
    path': String,
    caps': FileCaps val = recover val FileCaps .> all() end)
    ?
  =>
    caps.union(caps')
    if not base.caps(FileLookup) then
      error
    end

    let tmp_path = Path.join(base.path, path')
    caps.intersect(base.caps)

    if not tmp_path.at(base.path, 0) then
      error
    end
    path = tmp_path
```

# How We Teach This

Nothing about our teaching should need to change, however this change will allow early tutorials to avoid introducing try-else blocks and partial functions for longer if they so choose. For example, with a separate `FilePath` constructor an early tutorial could construct a `FilePath` for a file in the current directory containing a simple message, constructor the necessary `File`, and call `File.read()` or `File.lines`, none of which would be partial functions after this change -- such a program is just beyond the complexity of the ever ubiquitous "Hello, World" initial lesson.

Advanced users of Pony, should have little difficulty switching based on the simple statistics from stdlib below.

- Uses of `FilePath`: 166
- Uses of `FilePath(...)` from `AmbientAuth`: 37
- Uses of `_ as FilePath` typing: 19
- Uses of `FilePath(...)` not from `AmbientAuth`: 29
- Uses referring to `FilePath` for its type (e.g., within unions): 53
- Uses excluding the above (mostly documentation): 28

# How We Test This

At least one additional unit test is recommended as nearly all existing tests use `AmbientAuth`. It should suffice for this added unit test to first build a path via `AmbientAuth` then build a second path from the first.

Existing unit tests will need to change as the common phrase `let filepath = FilePath(h.env.root as AmbientAuth, path)?` will not fail. As well, `var tmp_dir: (FilePath | None) = ...` will likely not be needed as this is a defense against `FilePath` failing within a try statement.

# Drawbacks

- Breaks existing code
- Added maintenance cost
- May lead to passing `AmbientAuth` around excessively since building from an existing path (`FilePath.from...)`) will become less appealing

I am not sure we can change how this RFC is implemented to minimize any of the above. The first two are expected with additional breaking code as important as a constructor. The latter is a training issue so is best handled by better educational materials around Pony for _why_ it would be a "bad idea" to pass `AmbientAuth` around excessively.

# Alternatives

Keeping the implementation as it currently is written. There is nothing wrong with the existing implementation, this RFC is a suggestion for making the file package slightly easier to use.

# Unresolved questions

Does this have farther reaching affects beyond what is initially seen? Are there current patterns outside of stdlib for managing `FilePath`s?

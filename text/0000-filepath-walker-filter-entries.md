- Feature Name: filepath_walker_filter_entries
- Start Date: 2019-08-14
- RFC PR:
- Pony Issue:

# Summary

This RFC proposes changing the `WalkerHandler.apply` method that is used by `FilePath.walk` by requiring the user to return an `Array` of subdirectories to walk. Currently the `WalkerHandler.apply` method takes an argument called `dir_entries`, which is an `Array[String]` of subdirectories, and the user can remove items from the array to prevent them from being walked. This would allow the user to filter the subdirectories like this:

```pony
class MyWalkerHandler is WalkerHandler
  fun ref apply(dir_path: FilePath, dir_entries: Array[String] ref): Array[String] box =>
    let skip_directories_with_string = "IGNORE_ME"
    let filtered_directories = Array[String]

    for e in dir_entries.pairs() do
      if not e.contains(skip_directories_with_string) then
        filtered_directories.push(e)
      end
    end

    filtered_directories
```

If no filtering is needed then the user can simply return the array that was passed as `dir_entries`.

# Motivation

It is cumbersome to remove items from the `dir_entries` array. The `Array` API supports three methods for removing items from an array: `pop`, `shift`, and `remove`. `pop` and `shift` only work on the front and back of an array, so they are only useful in limited contexts. `remove` can remove items from any position in the array, but once the items are removed then the array indexes change for all items after the point of removal. This means that you can't iterate through an array and remove items that meet your criteria for removal. Consider the following example, which is intended to skip walking directories that have names that contain the string `"IGNORE_ME"`:

```pony
// incorrect way to filter dir_entries
class MyWalkerHandler is WalkerHandler
  fun ref apply(dir_path: FilePath, dir_entries: Array[String] ref) =>
    let skip_directories_with_string = "IGNORE_ME"
    for (i, e) in dir_entries.pairs() do
      if e.contains(skip_directories_with_string) then
        e.remove(i) // this causes subsequent uses of i to remove the wrong item
      end
    end
```

`i` is the index of the current array item, but the array is being modified by the loop so after the first removal all subsequent indexes will be off by one. There are serveral ways to get around this:

* iterate through the list backwards, so that removals do not impact the index of subsequent items
  ```pony
  class MyWalkerHandler is WalkerHandler
    fun ref apply(dir_path: FilePath, dir_entries: Array[String] ref) =>
      let skip_directories_with_string = "IGNORE_ME"
      var i = dir_entries.size()
      try
        while (i > 0) do
          i = i - 1
          if dir_entries(i)?.contains(skip_directories_with_string) then
            e.remove(i)
          end
        end
      end
  ```
* keep track of the current index yourself
  ```pony
  class MyWalkerHandler is WalkerHandler
    fun ref apply(dir_path: FilePath, dir_entries: Array[String] ref) =>
      let skip_directories_with_string = "IGNORE_ME"
      var removals: USize = 0
      for (i, e) in dir_entries.pairs() do
        if e.contains(skip_directories_with_string) then
          e.remove(i - removals)
          removals = removals + 1
        end
      end
   ```
* create a new collection that only contains the entries you want to keep, then `clear` the `dir_entries` array and repopulate it based on the collection you created
  ```pony
  class MyWalkerHandler is WalkerHandler
    fun ref apply(dir_path: FilePath, dir_entries: Array[String] ref) =>
      let skip_directories_with_string = "IGNORE_ME"
      let keep = Array[String]
      for (i, e) in dir_entries.pairs() do
        if not e.contains(skip_directories_with_string) then
          keep.push(e)
        end
      end
      dir_entries .> clear().concat(keep.values())
  ```
* use `itertools` to create a new filtered collection, then `clear` the `dir_entries` array and repopulate it based on that collection
  ```pony
   use "itertools"

   class MyWalkerHandler is WalkerHandler
     fun ref apply(dir_path: FilePath, dir_entries: Array[String] ref) =>
       let skip_directories_with_string = "IGNORE_ME"

       dir_entries .> clear().concat(
         Iter[String](dir_entries.pairs()).filter(
           {(e) => not e.contains(skip_directories_with_string)}))
  ```

The first two of these options involve a bit of bookkeeping on the part of the user, which could be prone to bugs. The last two involve `clear`ing the `dir_entries` array and repopulating it, which seems awkward.

# Detailed design

`WalkHandler` would become:

```pony
interface WalkHandler
  """
  A handler for `FilePath.walk`.
  """
  fun ref apply(dir_path: FilePath, dir_entries: Array[String] ref): Array[String] box
```

This would allow the user to return the list of subdirectories to walk. `FilePath.walk` would be modfied to use the returned list of dictories, becoming:

```pony
fun val walk(handler: WalkHandler ref, follow_links: Bool = false) =>
    """
    Walks a directory structure starting at this.

    `handler(dir_path, dir_entries)` will be called for each directory
    starting with this one. The handler returns a list of which subdirectories
    to walk.
    """
    try
      with dir = Directory(this)? do
        var entries: Array[String] ref = dir.entries()?
        let walkable_entries = handler(this, entries)
        for e in walkable_entries.values() do
          let p = this.join(e)?
          let info = FileInfo(p)?
          if info.directory and (follow_links or not info.symlink) then
            p.walk(handler, follow_links)
          end
        end
      end
    else
      return
    end
```

See the Summary section for an example of how this would be used.

# How We Teach This

This can be taught by updating the documentation and calling attention to it in the release notes. There is no mention of directory walking in the tutorial, patterns, or other existing documentation other than the stdlib documentation. New users would learn about it from the stdlib documentation.

# How We Test This

The `_TestWalk` test will need to be modified to return the correct entries. We will also need to add a test that filters the directories and ensures that the directories that are filtered out are not walked.

# Drawbacks

This approach requires allocating a new array if you want to filter the incoming list, which would have a performance impact.

It also requires returning an array even if no filtering is done, which results in an extra line of code even in the most trivial case.

# Alternatives

An alternative solution would be to modify the `Array` API to make it easier to remove items. One option would be to add a `remove_items` method that takes an `Iterator[USize]` and removes items at those locations. The filtering code might then look like this:

```pony
class MyWalkerHandler is WalkerHandler
  fun ref apply(dir_path: FilePath, dir_entries: Array[String] ref) =>
    let skip_directories_with_string = "IGNORE_ME"
    let to_remove = Array[USize]

    for (i, e) in dir_entries.pairs() do
      if not e.contains(skip_directories_with_string) then
        to_remove.push(i)
      end
    end

    dir_entries.remove_items(to_remove.values())
```

This method might be useful for other cases outside of `WalkerHandler` where the user wants to remove items from an array. However, it the case of `WalkerHandler` it still requires allocating a new collection of some sort to keep track of the items to remove.

Not doing this would require users to continue to write slightly more complicated code to do their own bookkeeping when removing items from the array.

# Unresolved questions

None

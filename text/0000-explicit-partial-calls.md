- Feature Name: explicit-partial-calls
- Start Date: 2017-03-07
- RFC PR:
- Pony Issue:

# Summary

Change the language to require explicit indication of all partial calls.

# Motivation

In Pony control flow, it's a common pattern to have a `try` block that starts with a partial call that generates a result, then the rest of the block does something with that result:

```pony
try
  let foo = do_something()
  let bar = do_something_else(foo)
  let baz = do_another_thing(foo, bar)
  do_something_final(foo, bar, baz)
else
  deal_with_failure_in_some_way() // what exactly failed?
end
```

However as emphasized in the `else` block comment, it's not inherently obvious when reading the above code which call(s) are partial, and thus which call(s) could fail and trigger control flow to the `else` block. By convention, the first call is probably partial (otherwise it would be outside the `try` block), but this is not *necessarily* true (it is not enforced by the compiler), and it also isn't necessarily the *only* partial call in the `try` block.

In general, the reader cannot understand the control flow of a `try` block without looking up (or knowing by rote) the partiality of every single method in the call. Often a `try` block is small enough for the answer to be obvious, or for the burden of lookup to at least be minimal. However, as the `try` block grows in complexity, so does the cognitive overhead of what the reader has to mentally keep track of, and thus so does the potential for programmer errors.

It's critical for both the reader and writer of code to understand what conditions could cause control flow to jump to the `else` block, because it influences and informs what action must be taken there to deal with the failure. If there is some partial call that was not considered for the `else` block, it could invalidate the approach taken there to address the issue, or lead to accidentally swallowing an error condition in a very subtle and hard-to-audit bug.

Matters get worse when it comes to refactoring existing code. Even a carefully constructed and thoroughly-reasoned-about `try` block can be subject to this same danger when it comes time to refactor the code in it. The new code may contain new partial calls that weren't considered in the original reasoning, and have the potential to invalidate that reasoning.

Terrifyingly, even *remote* refactoring can have effects on the correctness of a `try` block. A method on another type (and even in another package) that has a call site in the block, which is refactored from being non-partial to being partial *will not trigger any kind of compiler error*. This means the refactor will go likely unnoticed and thus likely will be inappropriately swallowed as if it were another kind of failure that it is not. This class of bugs is a grave danger for the correctness of programs that exist over long periods of time (and thus over long periods of refactoring).

I personally have felt very troubled by this concern - I feel a sense of dread growing every time I increase the size of a `try` block, though the way Pony works it is often not possible to avoid doing so, other than refactoring to move some of the logic to a new private method (which has the often-undesirable effect of diassociating it from the surrounding code). Further, the standard lirbary contains many `try` blocks that are much larger than I feel comfortable dealing with or auditing, and the same concern is always present when I see them.

It's worth mentioning that all these concerns also apply to partial methods, in which any call in the method body could potentially be partial, and there's no immediately clear or auditable sign of exactly which call(s) are.

To address these concerns, this RFC proposes using a mandatory visual indication of every partial method call, at the call site.

This indication would serve as an easily auditable sign of control flow, so that readers (and writers) of code could immediately see what possible failures could cause an "early return" from a partial method body, or "jump to else" in a `try`-`else` block.

The indication would also be checked by the compiler, so that codebase maintainers would be certain of being notified by compiler errors of any changes in the partiality of method signatures, anywhere in their program. Letting changes like that go unnoticed (as we currently do) is a major source of bugs, so this aspect of the change will be a major win in terms of being able to reason about the control flow of programs as they (and their dependencies) change over time.

# Detailed design

Every call to a partial method would be required to be "decorated" with a question mark (`?`) after the parentheses, just as method signatures are.

Using the earlier example, if `do_something` and `do_another_thing` are partial methods, then the earlier snippet would now look like this:

```pony
try
  let foo = do_something()?
  let bar = do_something_else(foo)
  let baz = do_another_thing(foo, bar)?
  do_something_final(foo, bar, baz)
else
  // now we see exactly what the possible failures could be:
  // do_something, or do_another_thing.
  deal_with_failure_in_some_way()
end
```

# How We Teach This

Every Pony program in the standard library, examples, Pony patterns, and tutorials literature would need to be updated to use the indicator, so that they would compile with the new compiler feature.

The Pony tutorial section on partial methods would have to be amended to explain it.

# How We Test This

Relatively simple compiler unit tests can be devised to test the restrictions on call sites:

* calls to partial methods must have the `?` indicator
* calls to non-partial methods must not have the `?` indicator

# Drawbacks

* Necessitates changes to nearly every Pony program ever written. However, the changes will be quite straightforward (additions of the `?` symbol) and guided by informative compiler errors.

* Additional syntax burden (requiring the `?` at every partial call site). However this burden is rather light - only a single character, and easy to remember due to the relation with how the `?` is used in method signatures.

# Alternatives

* My original idea for a solution to these concerns was to change the meaning of `then` in a `try` block to indicate a block of code that can *depend on* a `try` expression (use references from it), but in which errors will not be caught. This would be a step in the right direction, but does not fully address all of the concerns discussed in the *Motivations* section. Also, as @sylvanc and @andymcn have noted, it is an "optional" form of checking, so only users that are actively concerned about this form of bugs will be able to benefit. The proposal in this RFC (which was originally proposed by @sylvanc) is mandatory, and resolves all the concerns in the *Motivations* section for all Pony code, instead of being limited only to code that "opts in".

* A variant on this proposal that was discussed was to move the `?` indicator to the end of the method name identifer, at both the call site and the method signature, so that a partial call would look like this: `do_something?()`. This would be an even more invasive change than the one proposed in this RFC since it would also require changing syntax for partial method signatures in all existing code, in addition to changing it for call sites. Also, I'm not fully sold on that proposal myself, though we could continue to discuss it as a potential alternative.

# Unresolved questions

None.
- Feature Name: Expose scheduler thread information in standard library
- Start Date: 2022-01-12
- RFC PR: (leave this empty)
- Pony Issue: (leave this empty)

# Summary

Add a pony primitive that exposes via Pony code information about the scheduler
and the number of threads available.

# Motivation

Currently, when users want to optimize the parallelizing work based on the maximum number of actors that can be run at a single time, we are pointing them to using the private runtime method `@ponyint_sched_cores()`.

This is problematic for two reasons:

1. We are pointing users at an internal implementation method that we haven't promised not to change.
2. We are requiring users to muck about with FFI for something that has become somewhat common for users wanting to maximize performance want to know.

By adding a new primitive from which this information can be obtained, we'll be
setting up a supported API that can be depended on to not change except via the RFC process.

# Detailed design

The new functionality will be added to a new `runtime_info` package that additional information about the runtime can be added to in the future. When this RFC is implemented, the only classes in `runtime_info` will be a single primitive `Scheduler`:

```pony
use @pony_schedulers[U32]()
use @pony_active_schedulers[U32]()

primitive Scheduler
  fun schedulers(auth: RuntimeInfoAuth): U32 =>
    @pony_schedulers()

  fun active_schedulers(auth: RuntimeInfoAuth): U32 =>
    @pony_active_schedulers()
```

The primitive will expose the two existing "what's going on with schedulers" statistics that are available. Currently, only the maximum available number of schedulers is regularly used (as far as I know), but it makes sense to me to expose the current number of active schedulers as well.

We'll replace the existing private functions:

- ponyint_sched_cores
- ponyint_active_sched_count

with:

- pony_schedulers
- pony_active_schedulers

which will be marked as `PONY_API`.

Additionally, we will define a single auth required to access runtime information. The auth will be defined in a file called `auth.pony`:

```pony
type RuntimeInfoAuth is (AmbientAuth | SchedulerInfoAuth)

primitive SchedulerInfoAuth
  new create(auth: AmbientAuth) => None
```

# How We Teach This

Standard library documentation like other standard library classes. I don't think there is anything about exposing this information that requires any changes at this time to patterns or the tutorial.

# How We Test This

This is hard to test using ponytest, but can be partially tested in conjunction with runtime options. We can create a libponyc-run test that sets the max number of scheduler threads and then in the test that our `scheduler_threads` call returns the same number.

There is no good way to test "active" as that can change over time and as such, that method on `primitive Scheduler` will be untested and we rely on the functionality not being broken in the runtime.

Given that each method is merely returning a single value from the runtime, I think this is sufficient coverage for the functions as we are already relying on
the runtime to be "working properly" for the information to be correct.

# Drawbacks

The design as detailed will break existing code that was relying on the `ponyint_` methods that we will remove if this RFC is adopted.

# Alternatives

- We could leave the existing `ponyint_` methods in place.
- We could not require an object capability to access scheduler info.

# Unresolved questions

Is "active schedulers" the right name to expose to users? It is the current number that aren't currently sleeping due to lack of work. Perhaps "active" isn't the best term to expose to users for that.

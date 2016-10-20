- Feature Name: Allow TCPConnectionNotify to cause TCPConnection to yield while receiving
- Start Date: 2016-09-30
- RFC PR: https://github.com/ponylang/rfcs/pull/39
- Pony Issue: https://github.com/ponylang/ponyc/issues/1343

# Summary

Allow `TCPConnectionNotify` instances some level of control over the rate at which they receive data from `TCPConnection`.

# Motivation

This comes from direct experience using the existing `TCPConnection` functionality at Sendence. We are heavy users of `expect` on `TCPConnection` in order to support framed protocols. Our `received` methods on notifiers are generally of the following form:

```pony
  fun ref received(conn: TCPConnection ref, data: Array[U8] iso) =>
    if _header then
      // convert the 4 byte header into a value for expect, aka payload length
      let expect = Bytes.to_u32(data(0), data(1), data(2), data(3)).usize()

      conn.expect(expect)
      _header = false
    else
      // do something with payload
      ...

      // reset expect for next 4 byte header
        conn.expect(4)
        _header = true
    end
```

This short of usage is why `expect` was initially added to `TCPConnection`. Upon usage, we found a serious drawback with this approach. `TCPConnection` will read up to 4k of data on a single behavior run and if there is still data available, it will then send itself a `_read_again` message to trigger more reading of additional data. It does this so that it doesn't hogged the scheduler while reading from the socket. This can work reasonably well in some scenarios but not others. 

In the framed protocol example above, if the message payloads are small then 4k of data can result in a lot of messages being sent from our `received` method to other actors in the application. In an application that is continously receiving data, this results in a very bursty scheduling experience.

After consulting with Sylvan, we changed `received` and `TCPConnection` to allow `received` to return a Boolean to indicate whether `TCPConnection` should continue sending more data on this behavior run.

We've found that for some workloads, we are able to get equal performance while greatly lowering latency by having `TCPConnection` call `_read_again` earlier than it otherwise would.

# Detailed design

The changes themselves are fairly simple. In `TCPConnectionNotify` we added Boolean return value on `received` so that the new method on the interface is:

```pony
  fun ref received(conn: TCPConnection ref, data: Array[U8] iso): Bool =>
    """
    Called when new data is received on the connection. Return true if you
    want to continue receiving messages without yielding until you read
    max_size on the TCPConnection.  Return false to cause the TCPConnection
    to yield now.
    """
    true
```

To preserve existing functionality, a programmer should always return `true` their `received` methods after this RFC is accepted.

To actually make this work, the following changes are needed in `TCPConnection`:

For Non-Windows systems, in `_pending_reads` the call to `_notify.received` logic becomes:

```pony
            if not _notify.received(this, consume data) then
              _read_buf_size()
              _read_again()
              return
            else
              _read_buf_size()
            end
          end
```

For Windows systems, `_notify_received` is called in `_complete_reads` as:

```pony

        _notify.received(this, consume data)
        _read_buf_size()
      end

      _queue_read()
```

There are no changes required to this as, by default, the Windows implementation acts as if you were to return `false` from `received` under the new non-Window implementation.

# How We Teach This

The change in docstring for notifier is enough in my mind for this RFC to be accepted, however, in general, the TCP support in Pony assumes the user knows how TCP operates at a lower level. It would be good one day to have a detailed guide on how TCP works and how to leverage it in Pony. That said, I think that day is in the distant future given our other more basic documentation needs.

# Drawbacks

For users on Non-Windows platforms, there's a small amount of overhead in checking the value returned from `received` which has to be incurred by all users whether they get value from this feature or not.

# Alternatives

Leave as is and allow a certain class of TCP using application to have bursty, ueven performance. If we want to address this feature, I don't see any other alternatives that wouldn't be part of a fairly substantial overhaul of how `TCPConnection` et al are implemented

# Unresolved questions

Is there a way to test this functionality? We currently don't have any tests for it as we are unfamiliar with any easy way to test that its working correctly using existing testing tools.

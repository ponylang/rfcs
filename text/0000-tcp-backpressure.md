- Feature Name: TCP backpressure
- Start Date: 2016-09-29
- RFC PR: 
- Pony Issue: 

# Summary

Add support for TCP backpressure to Pony's `TCPConnection` actor.

# Motivation

TCP provides backpressure to signal to applications that they need to slow down sending, however, currently Pony while itself being signaled that backpressure is being applied, doesn't surface that to application code. This means that even a well meaning, diligent programmer is unable to respond to backpressure by slowing down.

# Detailed design

Add 1 or 2 notification methods to `TCPConnectionNotify`. In the version we are running at Sendence, we added a single notifier method:

```pony
  fun ref throttled(conn: TCPConnection ref, status: Bool) =>
    """
    Called when there is a change in backpressure status of the connection
    """
    None
```

The method, like all other `TCPConnectionNotify` methods take a reference to the `TCPConnection` that has had a chance in backpressure status as well as a bool indicating if the connection is being throttled.

While we are using this single method at Sendence, I think there is a strong argument for using 2 methods: one for when backpressure is being applied and one for when its released. While these shouldn't be called all that often, in `TCPConnection` we know whether this is a backpressure release or application but we are requiring the programming to do an branch to determine what to do in the `throttled` method. That's extra instructions that we don't really need. Additionally, the boolean for status is a little nasty and not the greatest API.

Within `TCPConnection` we have added the following private methods:

```pony
  fun ref _apply_backpressure() =>
    ifdef not windows then
      _writeable = false
    end

    _notify.throttled(this, true)

  fun ref _release_backpressure() =>
    _notify.throttled(this, false)
```

For non Windows platforms:

`_apply_backpressure` is called `write_final`

```pony
            // Send as much data as possible.
            var len =
              @pony_os_send[USize](_event, data.cstring(), data.size()) ?
              
            if len < data.size() then
              // Send any remaining data later. Apply back pressure.
              _pending.push((data, len))
              _apply_backpressure()
            end
```

`_release_backpressure` is called in `_pending_writes` as:

```pony
          if (len + offset) < data.size() then
            // Send remaining data later.
            node() = (data, offset + len)
            _writeable = false
          else
            // This chunk has been fully sent.
            _pending.shift()

            if _pending.size() == 0 then
              // Remove back pressure.
              _release_backpressure()
            end
          end
```

For Windows:

`_apply_backpressure` is called in `write_final` as:

```pony
          if _pending.size() > 128 then
            // If more than 128 asynchronous writes are scheduled, apply
            // back pressure.
            _apply_backpressure()
          end
```

`_release_backpressure` is called in `_complete_writes` at the end of the method as:

```pony
      if _pending.size() < 64 then
        // If fewer than 64 asynchronous writes are scheduled, remove back
        // pressure.
        _release_backpressure()
      end
```

Digging into the design a bit more:

In practical usage you would use this by having a `throttled` method such as:

```pony
  fun ref throttled(sock: TCPConnection ref, value: Bool) =>
    _coordinator.pause_sending(value)
```

Where coordinator is another actor that can inform any actors sending to the `TCPConnection` to pause or resume sending.

# How We Teach This

* Document the new notifier method(s) in their corresponding doc string. 

Additionally, I think we should so an example of usage somewhere. This could be in the `TCPConnection` actor level docs, perhaps in a new program in `examples/` or as a Pony Pattern.

I'm not really sure what combo of the above we should do.

# Drawbacks

I can't think of a reason not to implement backpressure. We might choose to do it another way but I think a TCP implementation that doesn't support backpressure notification is an incomplete implementation.

# Alternatives

The only alternative I see is not implementing backpressure which I think is suboptimal. We have been using our implementation of TCP backpressure at Sendence for a couple months now and it has made our applications much more stable.

See various notes on Windows implementation below, we've made an attempt to support Windows but a possible alternative is to only implement the non-windows version as the IOCP version we have detailed is based on a heuristic and not on actual feedback from the OS. If we choose not to implement the Windows version, I suggest that we attempt to get the more Windows savvy members of the community to chime in on how we should support backpressure on Windows.

# Unresolved questions

1. Whether we should have 1 or 2 `TCPConnectionNotify` methods.

2. While we implemented backpressure for Windows, we haven't tested it as we don't run on Windows. Input from someone with more Windows IOCP experience would be appreciated. As far as I know, it's implemented correctly and should work but I'm not sure if there is a better way to go about it for Windows.

3. Assuming that Windows implementation is reasonable, the decision of how many entries to allow in `pending` before we apply backpressure and how many we have to drop down to before releasing is purely arbitrary.

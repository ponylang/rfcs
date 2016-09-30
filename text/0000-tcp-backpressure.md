- Feature Name: TCP backpressure
- Start Date: 2016-09-29
- RFC PR: 
- Pony Issue: 

# Summary

Add support for TCP backpressure to Pony's `TCPConnection` actor.

# Motivation

TCP provides backpressure to signal to applications that they need to slow down sending, however, currently Pony while itself being signaled that backpressure is being applied, doesn't surface that to application code. This means that even a well meaning, diligent programmer is unable to respond to backpressure by slowing down.

Additionally, currently Pony applications that are TCP receivers can't participate in this system as they have no way of preventing `TCPConnection` from continuing to read all available data.

# Detailed design

There are two different parts to backpressure:

Outgoing backpressure that is applied when we try to write
Incoming backpressure in the form of us pausing reading from an incoming socket because we can't handle more work.

These are referred to as "Write Backpressure" and "Read Backpressure" throughout this RFC as these terms relate to the actions our program is taking.

## Write Backpressure

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

`_apply_backpressure` is called in `write_final` as:

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

## Read backpressure

We also need to be able to pause incoming sockets from reading. The name `pause` could indicate stopping sending which this doesn't do. I'm stealing the term `mute` from @jemc for this.

We add a single function and additional behavior(s) to `TCPConnection`:

```pony
  be mute() =>
    _muted = true

  be unmute() =>
    _muted = false
```

or a single behavior

```pony
  be mute(muted: Bool) =>
    _muted = muted
```

This in turn is used keep us from reading. Because ASIO events to indicate that its ok to read are only delivered once, the way we need to approach this is to check on each read we are going to do if we are muted and if we are, we need to send ourselves a `read_again` message to try reading again. This result in a decent amount of spin and could possibly be improved performance wise but, `read_again` fits in with the existing design of `TCPConnection`. Doing something else should be a deeper performance fix PR (assuming there is a "something else").

For non windows, we check `_muted` in `_pending_reads` as:

```pony
  fun ref _pending_reads() =>
    """
    Read while data is available, guessing the next packet length as we go. If
    we read 4 kb of data, send ourself a resume message and stop reading, to
    avoid starving other actors.
    """
    ifdef not windows then
      try
        var sum: USize = 0

        if _muted then
          _read_again()
          return
        end
```

For Windows, we check `_muted` in `_complete_read` as:

```pony
      if (not _muted) and (_read_len >= _expect) then
        let data = _read_buf = recover Array[U8] end
        data.truncate(_read_len)
        _read_len = 0

        _notify.received(this, consume data)
        _read_buf_size()
      end
```

N.B. the `_muted` field is initialized to `false` on actor startup. IE, we start in an unmuted state.

# How We Teach This

* Document the new notifier method(s) in their corresponding doc string. 

Additionally, I think we should so an example of usage somewhere. This could be in the `TCPConnection` actor level docs, perhaps in a new program in `examples/` or as a Pony Pattern.

I'm not really sure what combo of the above we should do.

# Drawbacks

I can't think of a reason not to implement backpressure. We might choose to do it another way but I think a TCP implementation that doesn't support backpressure notification is an incomplete implementation.

# Alternatives

## Don't implement backpressure mechanisms

Don't implement this RFC and leave as is. This would mean, not backpressure hooks for now but a possibly better implementation could come later. I think not implementing anything is suboptimal. We have been using our implementation of outgoing TCP backpressure at Sendence for a couple months now and it has made our applications much more stable. 

## Entirely different IOCP implementation

See various notes on Windows implementation below, we've made an attempt to support Windows but a possible alternative is to only implement the non-windows version as the IOCP version we have detailed is based on a heuristic and not on actual feedback from the OS. If we choose not to implement the Windows version, I suggest that we attempt to get the more Windows savvy members of the community to chime in on how we should support backpressure on Windows.

## Enhance `mute` for better notifier support

Currently, if we choose to mute, it is done purely via a behavior that means it won't take effect immediately. When used in conjunction with notifiers, there are a couple enhancements to consider:

1. supply a `fun ref` to allow enhancements to immediately mute/unmute their enclosing `TCPConnection`. This function would in turn be called from the behavior(s) that are exposed to other actors.

2. with #1 in place, we could then choose to add the ability to short circuit an existing read in place. On non-Windows platforms (I'd have to look more into Windows) when using `expect()`, we could often find outselves in this scenario... we are in our notifier's `received` and decide we want to mute our incoming. Ideally we want this to stop reading immediately. However, with `expect` and `mute` as a behavior, we would finish reading up to our max which could be many additional `received` calls. If we were able to immediately change the value of `_muted` from a notifier, then in `_pending_reads` we could change:

```pony
          if sum >= _max_size then
            // If we've read _max_size, yield and read again later.
            _read_again()
            return
          end
```

to be

```pony
          if _muted or sum >= _max_size then
            // If we've read _max_size, yield and read again later.
            _read_again()
            return
          end
```

thereby ending reading as soon as possible. Note this doesn't come without a cost as in normal operation we've added an additional conditional check that happens on each call to `_pending_reads` above and beyond what we have already added elsewhere in this RFC.

At this time, I don't see any reason to add any enhanced notifier mute support as, while we could mute from the notifier, we would have no way to unmute and would stop reading forever. If at some point in the future, we could communicate with notifiers from outside the `TCPConnection` actor (there have been some informal conversations about this) it would make sense to consider this idea.

## Allow notifier to participate in "muting"

We could still allow the notifier to participate in "muting" by asking it if it is ready to receive more data. At each point where we currently check _muted, we could also call a new method `ready_to_receive` on the notifier that if it returned `false` would have the same impact as `_muted` being `true`. This has a decent amount of overhead per check and as such, I think shouldn't be pursued into such time as someone reports a need for it. This is what we are doing in our custom Sendence `net` code but its part of a larger customization. Given the changes in this RFC, I don't think it makes sense at this time but could becomes something worth considering as other changes happen in Pony.

## Future alternatives

I think that when "asynclambda" (no RFC opened yet), "embedded actors" (RFC PR #38) or any other RFC in that vein is accepted, it behooves us to revisit how we are doing backpressure hooks. As communication and compostion mechanisms in Pony are changed/improved, it would make sense to revisit backpressure and see if there are changes that should be made.

# Unresolved questions

1. Whether we should have 1 or 2 `TCPConnectionNotify` methods.

2. Whether we have 2 methods: `mute` and `unmute` or a single `mute` method that takes a `Bool` value.

3. While we implemented backpressure for Windows, we haven't tested it as we don't run on Windows. Input from someone with more Windows IOCP experience would be appreciated. As far as I know, it's implemented correctly and should work but I'm not sure if there is a better way to go about it for Windows.

4. Assuming that Windows implementation is reasonable, the decision of how many entries to allow in `pending` before we apply backpressure and how many we have to drop down to before releasing is purely arbitrary.

5. This method we take for stopping reading `mute` as a behavior has some possible issues. They all stem from it not happening immediately. Its another message which is sent, I assume this happens quickly but we'd need some real world stress testing to see how this performs under a variety of scenarios. It might turn out to be suboptimal. Otoh, we have tested the outgoing backpressure extensively and haven't encountered any issues.

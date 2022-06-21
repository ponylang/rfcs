- Feature Name: stdlib-term-mouse-input-plus
- Start Date: 2022-06-20
- RFC PR: 
- Pony Issue: 

## Summary

Enhance ANSI terminal support in package `term` with mouse input handling, additional ANSI escape codes to support alt buffer and cursor switching, and capture of SIGINT and SIGTSTP to handle `^C` and `^Z` as input.

**Table of contents**
- [Summary](#summary)
- [Motivation](#motivation)
- [Detailed design](#detailed-design)
  - [New `ANSINotify` methods](#new-ansinotify-methods)
  - [New `ANSI` escape codes](#new-ansi-escape-codes)
  - [Enhance `ANSITerm`](#enhance-ansiterm)
    - [Mouse input handling](#mouse-input-handling)
    - [Ctrl-C and Ctrl-Z input handling](#ctrl-c-and-ctrl-z-input-handling)
  - [ANSI terminal options](#ansi-terminal-options)
- [How We Teach This](#how-we-teach-this)
- [How We Test This](#how-we-test-this)
- [Drawbacks](#drawbacks)
- [Alternatives](#alternatives)
- [Reference Implementation](#reference-implementation)
- [Questions](#questions)
- [References](#references)

## Motivation

> Why are we doing this? 

Improve ANSI terminal application capabilities when implementing text-based UIs.

> What use cases does it support? 

Mouse input handling, alt buffer switching, cursor hiding and capturing missing control keys.

> What is the expected outcome?

Enable richer text UI applications with both key and mouse input and improved user experience.

## Detailed design

> This is the bulk of the RFC. Explain the design in enough detail for somebody familiar with the language to understand, and for somebody familiar with the compiler to implement. This should get into specifics and corner-cases, and include examples of how the feature is used.

### New `ANSINotify` methods

`fun ref mouse_down(button: U8, x: U32, y: U32)`
* This method is called whenever a mouse button is pressed
* `button` is either 0 (left), 1 (middle), 2 (right)
* `x` and `y` are the character coordinates below the mouse cursor

`fun ref mouse_up(button: U8, x: U32, y: U32) => None` 
* This method is called whenever a mouse button is released
* `button` is either 0 (left), 1 (middle), 2 (right)
* `x` and `y` are the character coordinates below the mouse cursor

`fun ref mouse_move(x: U32, y: U32) => None`
* This method is called whenever the mouse is moved while no button is pressed
* `x` and `y` are the character coordinates below the mouse cursor

`fun ref mouse_drag(button: U8, x: U32, y: U32) => None`
* This method is called whenever the mouse is moved while a button is pressed
* `button` is either 0 (left), 1 (middle), 2 (right)
* `x` and `y` are the character coordinates below the mouse cursor

`fun ref mouse_wheel(direction: U8, x: U32, y: U32) => None`
* This method is called whenever the mouse wheel is rolled in either direction. 
* `direction` is either 0 or 1
* `x` and `y` are the character coordinates below the mouse cursor

### New `ANSI` escape codes

The following new methods return escape codes that can be used to enable/disable different capabilities.

| Method                                   | Description                                |
| ---------------------------------------- | ------------------------------------------ |
| `fun cursor_save() : String`             | Save current cursor position               |
| `fun cursor_restore() : String`          | Restore last saved cursor position         |
| `fun cursor_hide() : String`             | Hide the terminal cursor                   |
| `fun cursor_show() : String`             | Show the terminal cursor                   |
| `fun switch_to_alt_screen() : String`    | Switch to the alternate screen buffer [^1] |
| `fun switch_to_normal_screen() : String` | Switch back to the normal screen buffer    |
| `fun mouse_enable() : String`            | Enable mouse input events                  |
| `fun mouse_disable() : String`           | Disable mouse input handling               |

### Enhance `ANSITerm`

#### Mouse input handling

When mouse input processing is enabled (via appropriate escape codes) the terminal will send additional CSI-like escape sequences for the various mouse activity. 

To handle these escape sequences and call the new `ANSINotify` mouse methods:

* define three additional states to the the input handling FSM: `_EscapeMouseStart`, `_EscapeMouseX`, `_EscapeMouseY`
* define two additional numeric member variables to collect mouse coordinates: `_esc_mouse_x`, `_esc_mouse_y`
* when in the `_EscapeCSI` state, match `<` to switch to the `_EscapeMouseStart` state
* when in the `_EscapeMouseStart` state
  * collect numerals to update `_esc_num`, which is used to later detect the event type
  * match `;` to switch to the `_EscapeMouseX` state
* when in the `_EscapeMouseX` state
  * collect numerals to update `_esc_mouse_x`
  * match `;` to switch to the `_EscapeMouseY` state
* when in the `_EscapeMouseY` state
  * collect numerals to update `_esc_mouse_y`
  * match `M` or `m` and use `_esc_num` do call private mouse event dispatchers 

#### Ctrl-C and Ctrl-Z input handling

By default when the user presses `^C` or `^Z` they respectively cause `SIGINT` and `SIGTSTP` signals. In a typical full-screen terminal program we want handle these keys along with all the other Control keys. 

When `ANSITerm` is instantiated:
* Use the `signals` API to setup signal handlers for `SIGINT` and `SIGTSTP`.
* When the signals are captured, call the terminal's associated `ANSINotify#apply` handler with the appropriate input key codes.

### ANSI terminal options

Trapping `SIGINT` and `SIGTSTP` by default will mean that an existing terminal app that doesn't use any of the additional capabilities will no longer be interrupted/stopped by `^C/^Z`. 

* To preserve backwards compatibility, define a trait `ANSITermOptions` with default options.
```pony
trait ANSITermOptions
  fun capture_ctrl_c() : Bool => false
  fun capture_ctrl_z() : Bool => false
```

* Modify the `ANSITerm` constructor to take an options parameter with default value of an object literal based on the trait.
```pony
actor ANSITerm
  // ...
  new create(
    notify: ANSINotify2 iso,
    source: DisposableActor,
    timers: Timers = Timers,
    options: ANSITermOptions val = object is ANSITermOptions end) => ...
```

This allows an application to choose to override the default options like, for example:
```pony
    let term = ANSITerm(_Listen(env), env.input where 
                        options = object is ANSITermOptions
                          fun capture_ctrl_c() : Bool => true
                          fun capture_ctrl_z() : Bool => true
                        end)
```

## How We Teach This

Via changes to the package's generated documentation.

## How We Test This

> How do we assure that the initial implementation works? How do we assure going forward that the new functionality works after people make changes? Do we need unit tests? Something more sophisticated? What's the scope of testing? Does this change impact the testing of other parts of Pony? Is our standard CI coverage sufficient to test this change? Is manual intervention required?

_Currently there is an example for `ANSITerm` and `Readline`; otherwise there are no tests in the repo._

* Add a new example that surfaces the new functionality to enable mouse input, screen switching.
* Any suggestions?

## Drawbacks

> Why should we *not* do this? 

None other than that this introduces new, albeit a small amount of, changes that enhance applications with terminal-based UI. 

## Alternatives

> What other designs have been considered? 

This extends the extending design in the `term` package.

> What is the impact of not doing this?

Richer terminal apps will need to rely on implementing their own terminal input handling. 

## Reference Implementation

The proposed changes have been implemented by making a copy of the `term` package and creating a temporary derivative with the enhancements. When/if the RFC is approved, I will be able to supply the implementation via a PR.

## Questions

> Some possible questions and draft answers on which I am open to be convinced otherwise. :)

1. ✅ Should the mouse coordinates use `U32` to match the coordinate types used by `ANSI.cursor()` method?
     * I was surprised to see `U32` used for text cursor coordinates as the terminal codes barely support 16-bit coordinate values. 
     * Nonetheless, I think the answer here is YES to avoid unnecessary conversions across methods for text coordinates.
2. ❓ Should on/off method pairs instead be defined as a single method with a boolean parameter? E.g. `cursor_visibility(show: Bool)` instead of `cursor_hide()/cursor_show()`
     * I prefer the verbs of the two methods, 
     * Still, having a single method with a boolean parameter is OK as long as it doesn't reduce the clarity of the method, especially since in `ANSI` the methods return escape codes.
3. ❓ Should separate screen buffer switching functions instead be defined as a single method with a type union parameter? E.g. `switch_to_screen(screen: AlternateScreen | NormalScreen)`
     * I don't recommend this. 
     * Two clearly named methods achieve the same goal and avoid polluting the class name-space without any improvement in readability.

## References

[^1] "The Alternate Screen Buffer" in *XTerm Control Sequences*; [link](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h2-The-Alternate-Screen-Buffer)

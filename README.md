# EasyBar

EasyBar is a lightweight, scriptable macOS status bar built with SwiftUI and Lua.

It combines fast native widgets with flexible Lua widgets, so you can use built-ins for common system data and add custom widgets when you need something more specific. EasyBar is designed for a clean workflow on macOS and integrates especially well with AeroSpace.

## Inspiration and scope

EasyBar is heavily inspired by [SketchyBar](https://github.com/FelixKratz/SketchyBar).

I used SketchyBar for years and it is a great product. EasyBar is not meant as a replacement. It is a more opinionated project that reflects my own setup and trade-offs.

A few choices are intentional:

- EasyBar is built specifically around AeroSpace
- there are no plans to support yabai
- the project prefers native Swift code wherever possible
- Lua is supported for custom widgets, but the core direction is to keep as much logic and UI in Swift as practical

So while EasyBar shares some ideas with SketchyBar, it aims to be a different kind of tool: a personal, strongly opinionated macOS bar focused on a Swift-first architecture and an AeroSpace-based workflow.

## Features

- Native macOS bar window built with SwiftUI
- Lua-powered custom widgets
- Native built-in widgets for common status items
- AeroSpace integration for spaces and focused app state
- Event-driven widget updates
- Hoverable popups and interactive widgets
- Fast reload flow for config and widgets
- Homebrew Cask install and upgrade flow

## Install

EasyBar is distributed through Homebrew in the `gi8lino/tap` tap.

Add the tap:

```bash
brew tap gi8lino/tap
```

Install EasyBar:

```bash
brew install --cask gi8lino/tap/easybar
```

Launch it:

```bash
open -a EasyBar
```

This installs:

- `EasyBar.app`
- `easybarctl`

You can check the CLI path with:

```bash
command -v easybarctl
```

## Upgrade

```bash
brew upgrade --cask gi8lino/tap/easybar
```

## Uninstall

```bash
brew uninstall --cask gi8lino/tap/easybar
```

## Start at login

EasyBar is an app, not a Homebrew background service.

After launching it once, add it to macOS login items if you want it to start automatically at login.

## Built-in widgets

EasyBar currently includes these native built-ins:

- `spaces`
- `front_app`
- `battery`
- `volume`
- `date`
- `time`
- `calendar`
- `cpu`

These built-ins are configured in `config.toml` under the `builtins.*` sections.

## How it works

EasyBar renders one bar window split into three regions:

- left
- center
- right

Widgets are placed into one of these regions and ordered with an `order` value.

There are two widget systems.

## Native widgets

Native widgets are implemented in Swift and are ideal for:

- system integrations
- low-overhead live data
- richer platform-specific UI
- tightly integrated features like spaces, volume, calendar, and focused app display

## Lua widgets

Lua widgets are loaded from your widgets directory and rendered through the EasyBar Lua runtime. They are ideal for:

- custom shell-driven widgets
- small prototypes
- personal workflow widgets
- event-driven status items

Full Lua widget authoring documentation lives in:

```text
./docs/LUA_WIDGETS.md
```

## Architecture overview

EasyBar is split into a few clear parts.

### App and window layer

The app boots through `EasyBarApp`, wires into AppKit with `AppDelegate`, and hosts the top-level borderless bar window through `BarWindowController`.

### Config system

Configuration is loaded from TOML through `Config` and the parsing files in `Sources/EasyBar/Config/`.

EasyBar supports:

- file-based config
- live config reloads
- per-built-in defaults and overrides

The config system is split by concern, for example:

- `Config.swift`
- `ConfigLoader.swift`
- `ConfigParsingCore.swift`
- `ConfigParsingHelpers.swift`
- `Config+Builtin*.swift`

### Event system

EasyBar has a typed internal event bus that bridges:

- native Swift widgets
- system event subscriptions
- the Lua runtime

App-wide events include things like:

- workspace changes
- focus changes
- volume changes
- power changes
- timer ticks
- calendar changes

Widget-scoped interaction events include:

- mouse enter
- mouse exit
- click
- scroll
- slider preview
- slider changed

### Lua runtime

Lua widgets run in a separate Lua process. EasyBar:

- starts the runtime
- loads all widget files from your widgets directory
- exchanges JSON messages over stdin and stdout
- routes Lua logs back into the main logger
- tracks required event subscriptions declared by widgets

### Widget state and rendering

Both native widgets and Lua widgets publish `WidgetNodeState` trees into the shared `WidgetStore`. SwiftUI renders that tree through `WidgetBar` and `WidgetNodeView`.

This gives both widget systems a common rendering model.

## Requirements

- macOS 14 or newer
- Lua available on your system
- optional: AeroSpace for spaces and focused-app integration

By default, EasyBar expects Lua at:

```text
/usr/local/bin/lua
```

You can override that in config.

## Configuration

EasyBar reads its config from:

```text
~/.config/easybar/config.toml
```

You can override the config path with:

```bash
EASYBAR_CONFIG_PATH=/path/to/config.toml
```

A minimal example:

```toml
[builtins.spaces]
enabled = true
position = "left"

[builtins.calendar]
enabled = true
position = "right"
```

The complete current example config is in:

```text
./config.toml
```

That file is the source of truth for supported config keys and defaults.

## Built-in widget notes

### Spaces

The spaces widget integrates with AeroSpace and shows:

- workspace labels
- running app icons
- focused workspace styling
- focused app highlighting

It supports options for:

- hiding empty spaces
- showing labels only for the focused space
- collapsing inactive spaces
- icon sizing and spacing
- active and inactive colors

The focused app icon border color is configured here:

```toml
[builtins.spaces.colors]
focused_app_border = "#00000000"
```

### Front app

Shows the currently focused application name and optionally its icon.

### Battery

Shows a battery icon and, depending on config, can show the percentage inline or in a popup.

### Volume

Supports both a standard slider and an expandable-on-hover slider mode.

### Date and time

Simple native text widgets with configurable format strings.

### Calendar

The calendar widget supports:

- item, stack, or inline anchor layouts
- a native popup
- today, tomorrow, and future event sections
- birthdays as a separate section
- per-section popup colors

### CPU

Shows a native CPU sparkline with configurable history length, line width, and color.

## AeroSpace integration

EasyBar uses AeroSpace for:

- workspace listing
- current workspace focus
- visible workspaces
- focused app resolution

The AeroSpace binary is resolved from common install paths, including:

- `/opt/homebrew/bin/aerospace`
- `/usr/local/bin/aerospace`
- `/Applications/AeroSpace.app/Contents/MacOS/aerospace`

If AeroSpace is not installed, widgets that depend on it will not show useful state.

## AeroSpace configuration

To keep the `spaces` and `front_app` widgets in sync, AeroSpace should notify EasyBar when the focused workspace or focused window changes.

AeroSpace runs `exec-and-forget` commands through `/bin/bash -c`, so using an absolute path for `easybarctl` is the safest option.

If EasyBar was installed with Homebrew in the default prefix, the command path is usually:

- Apple Silicon: `/opt/homebrew/bin/easybarctl`
- Intel: `/usr/local/bin/easybarctl`

Add this to your `~/.aerospace.toml`:

```toml
exec-on-workspace-change = [
  'exec-and-forget /opt/homebrew/bin/easybarctl --workspace-changed'
]

on-focus-changed = [
  'exec-and-forget /opt/homebrew/bin/easybarctl --focus-changed'
]
```

If your Homebrew installation uses a different prefix, replace the path accordingly. You can verify the correct path with:

```bash
command -v easybarctl
```

## Events

EasyBar is event-driven. Widgets can react to system changes and user interaction instead of polling all the time.

Examples of app events:

- `workspace_change`
- `focus_change`
- `volume_change`
- `mute_change`
- `calendar_change`
- `power_source_change`
- `charging_state_change`
- `system_woke`
- `minute_tick`
- `second_tick`
- `forced`

Examples of widget interaction events:

- `mouse.entered`
- `mouse.exited`
- `mouse.down`
- `mouse.up`
- `mouse.clicked`
- `mouse.scrolled`
- `slider.preview`
- `slider.changed`

## Logging

EasyBar logs through a central logger.

By default, it writes:

- `DEBUG` and `INFO` to stdout
- `WARN` and `ERROR` to stderr

You can enable debug logging with:

```bash
EASYBAR_DEBUG=1 /Applications/EasyBar.app/Contents/MacOS/EasyBar
```

Lua runtime logs are bridged back into the same logger.

## Live reload

EasyBar can watch `config.toml` and automatically reload when it changes.

When config reload happens, EasyBar reloads:

- config
- Lua widgets
- native widget registry
- dependent services like AeroSpace-backed views

This is controlled by:

```toml
[app]
watch_config = true
```

## IPC

EasyBar includes a Unix socket server for external triggers. Supported commands include:

- `workspace_changed`
- `focus_changed`
- `refresh`
- `reload_config`

These commands are used to trigger refreshes from outside the app.

## Development

Development is straightforward:

```bash
swift build
swift run EasyBar
```

For debug logging:

```bash
EASYBAR_DEBUG=1 swift run EasyBar
```

In normal day-to-day work, most of the interesting customization happens through:

- `config.toml`
- Lua widget files
- native widget code when adding built-ins

## Roadmap ideas

Some natural future improvements could include:

- richer popup layouts
- multi-monitor bar support
- more native built-ins
- stronger theming presets
- better widget examples
- packaged default config and starter widgets

## License

This project is licensed under the Apache 2.0 License. See the [LICENSE](LICENSE) file for details.

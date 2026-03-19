# EasyBar

EasyBar is a lightweight, scriptable macOS status bar built with SwiftUI and Lua.

It combines fast native widgets with flexible Lua widgets, so you can use built-ins for common system data and add custom widgets when you need something more specific. EasyBar is designed for a clean workflow on macOS and integrates especially well with AeroSpace.

## Inspiration and scope

EasyBar is heavily inspired by [SketchyBar](https://github.com/FelixKratz/SketchyBar).

I used SketchyBar for years and it is a great product. EasyBar is not meant as a replacement for it. It is a much more opinionated project that reflects my own preferred setup and trade-offs.

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
- Homebrew-managed background service support

## Install

EasyBar is distributed through Homebrew in the `gi8lino/homebrew-tap` tap.

Add the tap:

```bash
brew tap gi8lino/tap
```

Install EasyBar:

```bash
brew install gi8lino/tap/easybar
```

This installs:

- `EasyBar.app` inside the Homebrew Cellar
- `easybar` to launch EasyBar
- `easybarctl` for CLI control and IPC commands

## Start at login with Homebrew

Start EasyBar as a Homebrew-managed user service:

```bash
brew services start easybar
```

Stop it:

```bash
brew services stop easybar
```

Restart it:

```bash
brew services restart easybar
```

## Upgrade

```bash
brew upgrade gi8lino/tap/easybar
brew services restart easybar
```

## Uninstall

```bash
brew services stop easybar
brew uninstall gi8lino/tap/easybar
```

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

### Native widgets

Native widgets are implemented in Swift and are ideal for:

- system integrations
- low-overhead live data
- richer platform-specific UI
- tightly integrated features like spaces, volume, calendar, and focused app display

### Lua widgets

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

The config system is now split by concern, for example:

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
- exchanges JSON messages over stdin/stdout
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

`widgets_dir` is configured in `config.toml`.

## Minimal example config

```toml
[builtins.spaces]
enabled = true
position = "left"
order = 10

[builtins.calendar]
enabled = true
position = "right"
order = 30
```

## Configuration structure

The config is split into these main sections.

### `[app]`

App-level settings such as:

- `widgets_dir`
- `lua_path`
- `watch_config`

### `[bar]`

Bar layout settings:

- `height`
- `padding_x`

### `[bar.colors]`

Bar colors:

- `background`
- `border`

There is no global `text` config anymore.

### `[builtins.<name>]`

Each built-in widget has its own config section with shared placement fields:

```toml
[builtins.<name>]
enabled = true
position = "left"
order = 10
```

Most built-ins also use a shared style block:

```toml
[builtins.<name>.style]
icon = ""
text_color = ""
background_color = ""
border_color = ""
border_width = 0
corner_radius = 0
padding_x = 8
padding_y = 4
spacing = 6
opacity = 1
```

Some widgets also add content-specific sections like:

- `content`
- `layout`
- `text`
- `icons`
- `colors`
- `slider`
- `anchor`
- `events`
- `birthdays`
- `popup`

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

Shows a battery icon and, on hover, optionally the percentage.

### Volume

Supports both a standard slider and an expandable-on-hover slider mode.

### Date and time

Simple native text widgets with configurable date format strings.

### Calendar

The calendar widget supports:

- item, stack, or inline anchor layouts
- a native popup
- today, tomorrow, and future event sections
- birthdays as a separate section
- per-section popup colors

## Example config

```toml
[app]
widgets_dir = "~/.config/easybar/widgets"
lua_path = "/usr/local/bin/lua"
watch_config = true

[bar]
height = 32
padding_x = 10

[bar.colors]
background = "#111111"
border = "#222222"

[builtins.spaces]
enabled = true
position = "left"
order = 10

[builtins.spaces.style]
background_color = "#00000000"
border_color = "#00000000"
border_width = 0
corner_radius = 0
padding_x = 0
padding_y = 0
spacing = 0
opacity = 1

[builtins.spaces.layout]
spacing = 8
hide_empty = true
padding_x = 12
padding_y = 2
margin_x = 4
margin_y = 8
corner_radius = 8
focused_corner_radius = 8
focused_scale = 1.0
inactive_opacity = 0.85
max_icons = 4
show_label = true
show_icons = true
show_only_focused_label = false
collapse_inactive = false
collapsed_padding_x = 6
collapsed_padding_y = 4

[builtins.spaces.text]
size = 12
weight = "semibold"
focused_color = "#ffffff"
inactive_color = "#d0d0d0"

[builtins.spaces.icons]
size = 20
spacing = 4
corner_radius = 3
focused_app_size = 28
border_width = 1
focused_app_border_width = 1

[builtins.spaces.colors]
active_background = "#2b2b2b"
inactive_background = "#1a1a1a"
active_border = "#444444"
inactive_border = "#00000000"
focused_app_border = "#00000000"

[builtins.front_app]
enabled = true
position = "left"
order = 20

[builtins.front_app.style]
icon = "􀈔"
text_color = "#ffffff"
background_color = "#1a1a1a"
border_color = "#333333"
border_width = 1
corner_radius = 8
padding_x = 8
padding_y = 4
spacing = 6
opacity = 1.0

[builtins.front_app.content]
show_icon = true
show_name = true
fallback_text = "No App"
icon_size = 14
icon_corner_radius = 4

[builtins.battery]
enabled = true
position = "right"
order = 10

[builtins.battery.style]
icon = "🔋"
text_color = "#ffffff"
background_color = "#1a1a1a"
border_color = "#333333"
border_width = 1
corner_radius = 8
padding_x = 8
padding_y = 4
spacing = 10
opacity = 1.0

[builtins.battery.content]
show_percentage = true
unavailable_text = "n/a"
icon_size = 18
color_mode = "dynamic"
fixed_color = "#8aadf4"
display_mode = "tooltip"

[builtins.battery.colors]
high = "#8bd5ca"
medium = "#eed49f"
low = "#f5a97f"
critical = "#ed8796"

[builtins.calendar]
enabled = true
position = "right"
order = 30
```

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

When EasyBar runs through Homebrew services, Homebrew manages the log files for the service.

You can enable debug logging with:

```bash
EASYBAR_DEBUG=1 easybar
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

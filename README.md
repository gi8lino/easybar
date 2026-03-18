# EasyBar

EasyBar is a lightweight, scriptable macOS status bar built with SwiftUI and Lua.

It combines fast native widgets with flexible Lua widgets, so you can use built-ins for common system data and write your own widgets when you want something custom. EasyBar is designed for a clean workflow on macOS and integrates especially well with AeroSpace.

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
- Optional file logging
- Launch at login support

## Install

EasyBar is distributed through Homebrew in the `gi8lino/formulae` tap.

Add the tap:

```bash
brew tap gi8lino/formulae
```

Install EasyBar:

```bash
brew install easybar
```

This installs:

- `EasyBar.app`
- `easybar`

The `easybar` command is linked from inside the installed app bundle, so it always matches the installed EasyBar version.

If Homebrew asks for an explicit cask install, use:

```bash
brew install --cask easybar
```

### Upgrade

```bash
brew upgrade easybar
```

### Uninstall

```bash
brew uninstall easybar
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

There are two widget systems:

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

## Architecture overview

EasyBar is split into a few clear parts:

### App and window layer

The app boots through `EasyBarApp`, wires into AppKit with `AppDelegate`, and hosts the top-level borderless bar window through `BarWindowController`.

### Config system

Configuration is loaded from TOML through the `Config` type and its parsing helpers. EasyBar supports:

- file-based config
- environment overrides
- live config reloads
- built-in widget defaults

Default config values live in `ConfigDefaults.swift`.

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

You can override the widgets directory with:

```bash
EASYBAR_WIDGETS_PATH=/path/to/widgets
```

## Minimal example config

```toml
[app]
widgets_dir = "~/.config/easybar/widgets"
lua_path = "/usr/local/bin/lua"
watch_config = true

[bar]
height = 36
padding_x = 10

[bar.colors]
background = "#111111"
border = "#222222"
text = "#ffffff"
focused_app_border = "#ff3b30"

[builtins.spaces.style]
enabled = true
position = "left"
order = 10

[builtins.front_app.style]
enabled = true
position = "left"
order = 20

[builtins.volume.style]
enabled = true
position = "right"
order = 20

[builtins.date.style]
enabled = true
position = "right"
order = 30

[builtins.time.style]
enabled = true
position = "right"
order = 40

[builtins.calendar.style]
enabled = true
position = "right"
order = 50
```

## Configuration structure

The config is split into these main sections:

### `[app]`

App-level settings such as:

- `widgets_dir`
- `lua_path`
- `watch_config`

### `[app.logging]`

Optional file logging:

- `enabled`
- `file`

### `[bar]`

Bar layout settings:

- `height`
- `padding_x`

### `[bar.colors]`

Global bar colors:

- `background`
- `border`
- `text`
- `focused_app_border`

### `[builtins.<name>]`

Each built-in widget has its own config section.

Most built-ins use a shared style block:

```toml
[builtins.<name>.style]
enabled = true
position = "left"
order = 10
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
- active/inactive colors

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

AeroSpace runs `exec-and-forget` commands through `/bin/bash -c`, so using an absolute path for `easybar` is the safest option.

If EasyBar was installed with Homebrew in the default prefix, the command path is usually:

- Apple Silicon: `/opt/homebrew/bin/easybar`
- Intel: `/usr/local/bin/easybar`

Add this to your `~/.aerospace.toml`:

```toml
exec-on-workspace-change = [
  'exec-and-forget /opt/homebrew/bin/easybar --workspace-changed'
]

on-focus-changed = [
  'exec-and-forget /opt/homebrew/bin/easybar --focus-changed'
]
```

If your Homebrew installation uses a different prefix, replace the path accordingly. You can verify the correct path with:

```bash
command -v easybar
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

## Creating your own widgets

EasyBar supports custom Lua widgets loaded from your widgets directory.

Each widget file is executed inside its own scoped EasyBar API environment. Widgets can:

- add items and layouts
- subscribe to events
- run shell commands
- update themselves dynamically
- create popup content
- define per-widget defaults

The full widget authoring guide lives here:

```text
./docs/LUA_WIDGETS.md
```

That document should be the main reference for creating custom widgets.

A very small example might look like this:

```lua
easybar.default({
	position = "right",
	padding_left = 8,
	padding_right = 8,
})

easybar.add("item", "hello_widget", {
	label = "Hello",
	icon = "􀉉",
})

easybar.subscribe("hello_widget", "forced", function()
	easybar.set("hello_widget", {
		label = os.date("%H:%M:%S"),
	})
end)

easybar.subscribe("hello_widget", "second_tick", function()
	easybar.set("hello_widget", {
		label = os.date("%H:%M:%S"),
	})
end)
```

## Logging

EasyBar logs through a central logger and can also write logs to a file.

You can enable file logging in config:

```toml
[app.logging]
enabled = true
file = "~/Library/Logs/EasyBar.log"
```

You can also enable debug logging with:

```bash
EASYBAR_DEBUG=1
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

## Launch at login

EasyBar includes a small Settings window with launch-at-login support through `SMAppService`.

This requires macOS 13 or newer.

## Project structure

```text
Sources/EasyBar/
  App/         app lifecycle, window, settings
  Config/      config models, defaults, parsing, reload
  Core/        shared models, theme, logger
  Events/      system and widget event bridge
  IPC/         unix socket server for external triggers
  Lua/         runtime and Lua-side framework
  Services/    AeroSpace and file watching services
  Widgets/     native widgets, runtime bridge, shared state, SwiftUI views

Sources/EasyBarShared/
  shared code used by app and CLI
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

# EasyBar

[![EasyBar screenshot](assets/bar.png)](assets/bar.png)

EasyBar is a lightweight, scriptable macOS status bar built with SwiftUI and Lua.

It combines fast native widgets with flexible Lua widgets. Use built-ins for common system data, then add custom Lua widgets when you need something specific.

EasyBar is designed for a clean macOS workflow and integrates especially well with AeroSpace.

## Start here

If you're new to EasyBar, this is the quickest path:

1. Follow [Installation](getting-started/installation.md).
2. Confirm where EasyBar reads config in [Config Path](getting-started/configuration-path.md).
3. Decide between [Built-ins Vs Lua](getting-started/builtins-vs-lua.md).
4. Skim [Configuration Overview](configuration/overview.md).
5. Choose or customize a [Theme](configuration/themes.md).
6. Open [Lua Widgets](lua/overview.md) when you want custom behavior.
7. Use [Troubleshooting](runtime/troubleshooting.md) if the bar or agents do not come up cleanly.

## Features

- Native macOS bar window built with SwiftUI
- Native built-in widgets plus Lua widgets
- File-based themes with bundled and custom TOML palettes
- Object-style Lua widget API with node handles
- AeroSpace integration for spaces, focused app state, and layout mode state
- Event-driven updates and interactive popups
- Calendar and network helper agents for permission-sensitive data
- Homebrew install and service workflow
- Logging and startup diagnostics for troubleshooting
- Lightweight runtime metrics

## How EasyBar is meant to be used

- Start with built-in widgets for battery, Wi-Fi, spaces, calendar, and other system-integrated data.
- Use a bundled theme or a custom TOML theme for shared visual defaults.
- Override exact colors in `config.toml` when a specific widget should look different.
- Reach for Lua widgets when you need custom display logic, event handling, shell integration, or app-specific behavior.
- Keep platform-sensitive logic in native code when possible, and treat Lua as the extension layer.

If you are choosing between built-ins and Lua, start with [Built-ins Vs Lua](getting-started/builtins-vs-lua.md).

## Project scope

EasyBar is heavily inspired by [SketchyBar](https://github.com/FelixKratz/SketchyBar).

EasyBar is not meant to be a drop-in replacement. It is a more opinionated project that reflects a specific macOS setup and a few intentional trade-offs:

- EasyBar is built specifically around AeroSpace.
- There are no plans to support yabai.
- Native Swift code is preferred wherever possible.
- Lua is supported for custom widgets, but the core direction is Swift-first.

EasyBar shares some ideas with SketchyBar, but aims to be a different kind of tool: a personal, strongly opinionated macOS bar focused on native Swift UI, helper agents, and an AeroSpace-based workflow.

## Screenshots

### Calendar

[![Calendar screenshot](assets/month.png){ .screenshot-compact }](assets/month.png)

### Upcoming

[![Upcoming screenshot](assets/upcoming.png){ .screenshot-compact }](assets/upcoming.png)

### CPU

[![CPU screenshot](assets/cpu.png)](assets/cpu.png)

### Wifi

[![WiFi screenshot](assets/wifi.png)](assets/wifi.png)

### Front app

[![Front app screenshot](assets/front_app.png)](assets/front_app.png)

### Context menu

[![Context menu screenshot](assets/context.png)](assets/context.png)

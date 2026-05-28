# EasyBar

![EasyBar screenshot](./docs/content/assets/bar.png)

EasyBar is a lightweight, scriptable macOS status bar built with SwiftUI and Lua.

It combines native built-in widgets with custom Lua widgets and is designed for an AeroSpace-based macOS workflow.

## Features

- Native macOS bar window built with SwiftUI
- Built-in widgets plus scriptable Lua widgets
- File-based themes with bundled and custom TOML palettes
- AeroSpace integration for spaces, focused app state, and layout mode state
- Event-driven updates and interactive popups
- Calendar and network helper agents
- Homebrew install and service workflow
- Config-driven logging and troubleshooting support
- Lightweight runtime metrics

## Installation

```bash
brew tap gi8lino/tap
brew install gi8lino/tap/easybar
```

Start EasyBar and its helper agents:

```bash
brew services start gi8lino/tap/easybar-calendar-agent
brew services start gi8lino/tap/easybar-network-agent
brew services start gi8lino/tap/easybar
```

## Documentation

Full documentation is available here: [https://gi8lino.github.io/easybar/](https://gi8lino.github.io/easybar/)

Start with:

- Installation
- Configuration
- Themes
- AeroSpace Integration
- Lua Widgets
- Troubleshooting
- Architecture

## Configuration

EasyBar reads its runtime config from:

```text
~/.config/easybar/config.toml
```

You can override it with:

```bash
EASYBAR_CONFIG_PATH=/path/to/config.toml
```

The repository includes:

- [`config.defaults.toml`](./config.defaults.toml)
- [`config.minimal.toml`](./config.minimal.toml)

Themes are selected in `config.toml`:

```toml
[theme]
name = "mocha"
themes_dir = "~/.config/easybar/themes"
```

EasyBar first looks for a custom theme in `themes_dir`, then falls back to bundled themes.

## Screenshots

### Calendar

<img src="./docs/content/assets/month.png" alt="Calendar screenshot" width="320">

### Upcoming

<img src="./docs/content/assets/upcoming.png" alt="Upcoming screenshot" width="320">

### CPU

<img src="./docs/content/assets/cpu.png" alt="CPU screenshot" width="500">

### Front app

<img src="./docs/content/assets/front_app.png" alt="Front app screenshot" width="500">

### Context menu

<img src="./docs/content/assets/context.png" alt="Context menu screenshot" width="500">

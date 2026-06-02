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

## Developing

Quickstart for contributors:

```bash
make test
make stop
make run-debug
```

Useful build and runtime commands:

- `make test` runs the full Swift test suite.
- `make build` builds the local app, agents, and CLI artifacts.
- `make run-debug` starts EasyBar with verbose logging for local debugging.
- `make stop` stops the running EasyBar app and helper agents cleanly.
- `.build/arm64-apple-macosx/debug/EasyBarCtl --validate-config --config /path/to/config.toml` performs a dry-run config validation without starting the bar.

Helpful entry points in the codebase:

- `Sources/EasyBarApp/App` contains the main app shell and startup wiring.
- `Sources/EasyBarApp/Runtime` contains config reload, file watching, and socket orchestration.
- `Sources/EasyBarApp/Widgets` contains native widgets, Lua runtime integration, and rendered widget state.
- `Sources/EasyBarCalendarAgent` and `Sources/EasyBarNetworkAgent` contain the helper agent apps.
- `Sources/EasyBarShared` contains shared runtime, logging, socket, and protocol code used across targets.

If you want the architectural map before editing code, start with the docs sections for Architecture, Agents, and Lua Runtime in [the project docs](https://gi8lino.github.io/easybar/).

## Screenshots

### Calendar

<img src="./docs/content/assets/month.png" alt="Calendar screenshot" width="320">

### Upcoming

<img src="./docs/content/assets/upcoming.png" alt="Upcoming screenshot" width="320">

### CPU

<img src="./docs/content/assets/cpu.png" alt="CPU screenshot" width="500">

### Front app

<img src="./docs/content/assets/front_app.png" alt="Front app screenshot" width="500">

### Wifi

<img src="./docs/content/assets/wifi.png" alt="Wifi details view screenshot" width="500">

### Context menu

<img src="./docs/content/assets/context.png" alt="Context menu screenshot" width="500">

## License

This project is licensed under the Apache 2.0 License. See [LICENSE](./LICENSE) for details.

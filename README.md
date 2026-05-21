# EasyBar

![EasyBar](./docs/assets/icons/favicon-64x64.png)
![EasyBar screenshot](./docs/assets/bar.png)

EasyBar is a lightweight, scriptable macOS status bar built with SwiftUI and Lua.

It combines native built-in widgets with custom Lua widgets and is designed for an AeroSpace-based macOS workflow.

## Features

- Native macOS bar window built with SwiftUI
- Built-in widgets plus scriptable Lua widgets
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

Full documentation is available here:

```text
https://gi8lino.github.io/easybar/
```

Start with:

- Installation
- Configuration
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

## Screenshots

### Calendar

![Calendar screenshot](./docs/assets/month.png)

### Upcoming

![Upcoming screenshot](./docs/assets/upcoming.png)

### CPU

![CPU screenshot](./docs/assets/cpu.png)

### Front app

![Front app screenshot](./docs/assets/front_app.png)

### Context menu

![Context menu screenshot](./docs/assets/context.png)

## License

This project is licensed under the Apache 2.0 License. See [LICENSE](./LICENSE) for details.

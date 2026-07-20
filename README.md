# EasyBar

![EasyBar screenshot](./docs/content/assets/bar.png)

EasyBar is a lightweight, scriptable macOS status bar built with SwiftUI and Lua. It combines
native widgets with custom Lua widgets and integrates with AeroSpace.

## Features

- Native widgets for spaces, apps, system status, calendar, and more
- Scriptable Lua widgets with events, popups, groups, and context menus
- Shared inbox with unread state, grouping, Markdown, and widget actions
- File-based TOML themes and comment-preserving configuration updates
- AeroSpace integration and separate calendar and network helper agents
- Menu bar controller and CLI for runtime control and diagnostics

<p align="center">
  <img src="./docs/content/assets/inbox.png" alt="EasyBar inbox" width="520">
</p>

## Requirements

- macOS 14 Sonoma or newer
- [Homebrew](https://brew.sh/) for installation
- AeroSpace 0.21.0 or newer when using AeroSpace-backed widgets

## Installation

```bash
brew tap gi8lino/tap
brew install --cask gi8lino/tap/easybar
open -a EasyBar
```

See the [installation guide](https://gi8lino.github.io/easybar/getting-started/installation/)
for upgrades, verification, and removal.

## Documentation

The full documentation is available at
[gi8lino.github.io/easybar](https://gi8lino.github.io/easybar/).

- [Quick start](https://gi8lino.github.io/easybar/getting-started/quick-start/)
- [Configuration](https://gi8lino.github.io/easybar/configuration/overview/)
- [Themes](https://gi8lino.github.io/easybar/configuration/themes/)
- [Lua widgets](https://gi8lino.github.io/easybar/lua/overview/)
- [Runtime and troubleshooting](https://gi8lino.github.io/easybar/runtime/troubleshooting/)
- [Development](https://gi8lino.github.io/easybar/internals/development/)

The complete defaults and a small starter configuration are also available in
[`config.defaults.toml`](./config.defaults.toml) and [`config.minimal.toml`](./config.minimal.toml).

## License

Licensed under the [Apache License 2.0](./LICENSE).

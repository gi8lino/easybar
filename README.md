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
- Homebrew cask installation into `/Applications`
- Config-driven logging and troubleshooting support
- Lightweight runtime metrics

## Requirements

EasyBar v0.4.0 and newer require AeroSpace 0.21.0 or newer for AeroSpace-backed widgets. The integration reads AeroSpace state from formatted JSON output.

If you use v0.4.0 or newer, update and restart AeroSpace so both the CLI client and the running AeroSpace.app server are at least 0.21.0.

Check your installed AeroSpace versions with:

```bash
aerospace --version
```

## Installation

```bash
brew tap gi8lino/tap
brew install --cask gi8lino/tap/easybar
```

Launch EasyBar from Finder, Spotlight, or the command line:

```bash
open -a EasyBar
```

## Documentation

Full documentation is available here: [https://gi8lino.github.io/easybar/](https://gi8lino.github.io/easybar/)

Start with:

- Installation
- Configuration
- Themes
- AeroSpace Integration
- Lua Widgets
- Runtime Control
- Troubleshooting
- Architecture

## Configuration

EasyBar can start without a custom config file. Create one only when you want to override the built-in defaults.

When present, EasyBar reads its runtime config from:

```text
~/.config/easybar/config.toml
```

You can override it with:

```bash
EASYBAR_CONFIG_PATH=/path/to/config.toml
```

The repository includes:

- [`config.defaults.toml`](./config.defaults.toml) for the complete default reference
- [`config.minimal.toml`](./config.minimal.toml) for a small optional starter override

Themes are selected in `config.toml`:

```toml
[theme]
name = "default"
themes_dir = "~/.config/easybar/themes"
```

EasyBar first looks for a custom theme in `themes_dir`, then falls back to bundled themes.

## Developing

### Test the release bundles

Build the local ad-hoc-signed bundles and launch the standalone agents before the main app:

```bash
make bundle ARCH=arm64 VERSION=dev
open -g dist/EasyBarCalendarAgent.app
open -g dist/EasyBarNetworkAgent.app
open dist/EasyBar.app
```

The calendar and network helpers are standalone application bundles installed through separate Homebrew formulae and managed by Homebrew Services. EasyBar communicates with them over Unix sockets. The CLI remains a separate `dist/easybar` executable.

Restart helpers with `easybar --restart-calendar-agent`, `easybar --restart-network-agent`, or `easybar --restart-agents`.

### Install the current checkout for longer testing

After installing one released EasyBar version through Homebrew, install the current checkout over that installation with:

```bash
make install-local
```

This builds release-mode artifacts for `LOCAL_INSTALL_ARCH` (which defaults to `RUN_ARCH`), replaces the app in `/Applications`, overlays the CLI and both Homebrew-managed agent bundles, restarts the agent services, and launches EasyBar. Repeat the command whenever you want to test a newer local state without creating a release.

Use another architecture or app directory when needed:

```bash
make install-local LOCAL_INSTALL_ARCH=universal
make install-local LOCAL_APP_DIR="$HOME/Applications"
```

The target intentionally modifies the installed Homebrew package files. Restore the latest released build at any time with:

```bash
brew reinstall gi8lino/tap/easybar-calendar-agent gi8lino/tap/easybar-network-agent
brew reinstall --cask gi8lino/tap/easybar
```

Quickstart for contributors:

```bash
make test
make stop
make run-debug
```

Useful build and runtime commands:

- `make verify-source-tree` checks required source, packaging, and Homebrew cask inputs.
- `make test` runs the full Swift test suite without regenerating checked-in artifacts.
- `make build` builds the local app, agents, and CLI artifacts.
- `make run-debug` starts EasyBar with verbose logging for local debugging.
- `make install-local` installs the current release-mode checkout over the existing Homebrew installation.
- `make stop` stops the running EasyBar app and helper agents cleanly.
- `make validate-config CONFIG=/path/to/config.toml` builds the CLI and asks EasyBar to dry-run config validation without reloading the bar.

## Generated artifacts

Regenerate checked-in generated files before committing changes to theme tokens, event catalog data, Lua API stubs, or generated Lua reference docs:

```bash
make generate
```

Regenerate only generated documentation when the runtime or Lua API docs changed:

```bash
make generate-docs
```

Before opening a pull request, verify that generated files are current:

```bash
make check-generated
```

## Helper scripts

Reusable automation lives under `scripts/` and is grouped by purpose:

- `scripts/ci/` contains CI-only wrappers such as dependency setup and long-running Swift test logging.
- `scripts/release/` contains release automation such as Homebrew cask rendering and tap commits.
- Existing generator scripts remain the source of truth for generated Swift, Lua, and documentation artifacts and are still orchestrated through the Makefile.

Keep local developer entrypoints in the Makefile where possible, and move only reusable implementation details into scripts. That keeps commands like `make generate`, `make build-docs`, and `make package` stable while avoiding large shell blocks in workflows.

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

### Wi-Fi

<img src="./docs/content/assets/wifi.png" alt="Wi-Fi details view screenshot" width="500">

### Context menu

<img src="./docs/content/assets/context.png" alt="Context menu screenshot" width="500">

### Topbar

<img src="./docs/content/assets/topbar.png" alt="Topbar screenshot" width="200">

## License

This project is licensed under the Apache 2.0 License. See [LICENSE](./LICENSE) for details.

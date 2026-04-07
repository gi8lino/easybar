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
- Native built-in widgets plus Lua widgets
- AeroSpace integration for spaces, focused app state, and layout mode state
- Event-driven updates and interactive popups
- Calendar and network helper agents for permission-sensitive data
- Homebrew install and service workflow
- Logging and startup diagnostics for troubleshooting

## Install

EasyBar is distributed through Homebrew in the `gi8lino/tap` tap.

Add the tap:

```bash
brew tap gi8lino/tap
```

Install EasyBar:

```bash
brew install gi8lino/tap/easybar
```

This also installs the calendar and network helper agents. Start all services:

```bash
brew services start gi8lino/tap/easybar-calendar-agent
brew services start gi8lino/tap/easybar-network-agent
brew services start gi8lino/tap/easybar
```

> [!NOTE]
> By using EasyBar, you acknowledge that it is not notarized.
>
> Notarization is one of Apple's distribution checks. In practice, it means sending binaries to Apple and dealing with their packaging and approval flow.
>
> I do not mind the general idea of signing or notarization. I specifically do not want to spend time dealing with Apple's developer account, notarization pipeline, and release bureaucracy for this project.
>
> The Homebrew install is meant to work out of the box in the common case. If macOS still blocks EasyBar or one of its helper agents with a Gatekeeper or malware verification warning on your machine, remove the quarantine attribute and start the services again.

If macOS blocks the app or CLI with a Gatekeeper or malware verification warning, remove quarantine and start it again:

```bash
xattr -dr com.apple.quarantine "$(brew --prefix)/opt/easybar/libexec/EasyBar.app"
xattr -dr com.apple.quarantine "$(brew --prefix)/opt/easybar-calendar-agent/libexec/EasyBarCalendarAgent.app"
xattr -dr com.apple.quarantine "$(brew --prefix)/opt/easybar-network-agent/libexec/EasyBarNetworkAgent.app"
xattr -d com.apple.quarantine "$(command -v easybar)"
brew services start gi8lino/tap/easybar-calendar-agent
brew services start gi8lino/tap/easybar-network-agent
brew services start gi8lino/tap/easybar
```

## Agents

EasyBar uses two small helper agents:

- `easybar-calendar-agent`
  owns `EventKit`, requests Calendar permission, watches calendar changes, and pushes cached snapshots to EasyBar over a local Unix socket
- `easybar-network-agent`
  owns Wi-Fi and network state that depends on location permission, watches network changes, and pushes snapshots to EasyBar over a local Unix socket

This keeps permission-sensitive APIs out of the main UI process and makes those widgets more reliable.

Both agents are enabled by default and can be turned off independently in `config.toml` with:

```toml
[agents.calendar]
enabled = true

[agents.network]
enabled = true
```

For the network agent, you can also decide what happens when location permission is denied:

```toml
[agents.network]
allow_unauthorized_non_sensitive_fields = false
```

The default is privacy-first: requests for Wi-Fi fields fail until location access is granted.

More details live in [docs/AGENTS.md](./docs/AGENTS.md).

## Control socket

EasyBar exposes one local Unix control socket for `easybar` and other clients.

Commands are sent as typed JSON requests, not raw strings:

```json
{
  "command": "refresh"
}
```

Responses are typed too:

```json
{
  "status": "accepted",
  "message": null
}
```

Supported commands:

- `workspace_changed`
- `focus_changed`
- `space_mode_changed`
- `refresh`
- `reload_config`

`easybar` already speaks this protocol, so most users should use the CLI instead of talking to the socket directly.

### AeroSpace layout mode example

If you use the built-in AeroSpace mode widget, you should trigger EasyBar whenever you change the current layout mode in AeroSpace.

For example:

```toml
alt-e = [
  'layout tiles horizontal',
  'exec-and-forget /opt/homebrew/bin/easybar --space-mode-changed'
]
alt-v = [
  'layout tiles vertical',
  'exec-and-forget /opt/homebrew/bin/easybar --space-mode-changed'
]
alt-s = [
  'layout v_accordion',
  'exec-and-forget /opt/homebrew/bin/easybar --space-mode-changed'
]
alt-shift-space = [
  'layout floating tiling',
  'exec-and-forget /opt/homebrew/bin/easybar --space-mode-changed'
]
```

That tells EasyBar to refresh its AeroSpace-derived state after the layout mode changes, so widgets like the built-in AeroSpace mode widget update immediately.

## Configuration

EasyBar reads its runtime config from:

```text
~/.config/easybar/config.toml
```

You can override that path with:

```bash
EASYBAR_CONFIG_PATH=/path/to/config.toml
```

A small example:

```toml
[builtins.spaces]
enabled = true

[builtins.calendar]
enabled = true
```

The repository includes two config examples:

- [config.defaults.toml](./config.defaults.toml)
  full reference file with the current defaults and supported sections
- [config.minimal.toml](./config.minimal.toml)
  smaller starter example with a native `system` group

Config details, native groups, and example layouts are documented in [docs/CONFIG.md](./docs/CONFIG.md).

## Troubleshooting

When something is wrong, the first thing to do is check whether EasyBar and its helper agents are actually running, whether they are duplicated, and whether the logs show a clear startup warning.

### Quick checks

Check the Homebrew services:

```bash
brew services list | grep easybar
```

Check running processes:

```bash
pgrep -fl EasyBar
pgrep -fl easybar-calendar-agent
pgrep -fl easybar-network-agent
```

Check that only one main EasyBar process is running. EasyBar now refuses to start when another instance already holds its lock, but duplicate service or manual launches are still the first thing to rule out.

Check the control socket with the CLI:

```bash
easybar --refresh
```

If that fails, EasyBar may not be running, may have been blocked by macOS, or may have failed during startup.

### Logs

If logging is enabled in your config, EasyBar writes useful startup information such as:

- bundle path and executable path
- config path and widget path
- enabled agents and socket paths
- screen geometry
- environment overrides
- whether required fonts are available
- whether another EasyBar instance is already running

Enable logging in `config.toml`:

```toml
[logging]
enabled = true
debug = true
```

Then inspect the log output in your configured logging directory.

If you installed with Homebrew and are using services, also check Homebrew service logs:

```bash
tail -n 200 ~/Library/Logs/Homebrew/easybar/*.log
tail -n 200 ~/Library/Logs/Homebrew/easybar-calendar-agent/*.log
tail -n 200 ~/Library/Logs/Homebrew/easybar-network-agent/*.log
```

If your Homebrew setup writes logs somewhere else on your machine, use `brew services info easybar` and the corresponding agent services to find the actual paths.

### Common problems and fixes

#### EasyBar does not appear

Check whether the service is running:

```bash
brew services list | grep easybar
```

Try launching the app directly:

```bash
open "$(brew --prefix)/opt/easybar/libexec/EasyBar.app"
```

If that works but the service does not, restart the services:

```bash
brew services restart gi8lino/tap/easybar-calendar-agent
brew services restart gi8lino/tap/easybar-network-agent
brew services restart gi8lino/tap/easybar
```

If nothing appears, check logs for startup warnings and macOS permission or quarantine problems.

#### Another instance is already running

EasyBar now uses a single-instance guard. If a second instance starts, it logs a warning and exits.

You can detect duplicates with:

```bash
pgrep -fl EasyBar
```

If you accidentally launched both a Homebrew service and a manual app instance, stop the extra one:

```bash
pkill -x EasyBar
brew services restart gi8lino/tap/easybar
```

If you are also testing local builds from `dist/`, stop all services first so you do not mix service and manual runs.

#### Nerd Font icons look wrong or are clipped

EasyBar expects `Symbols Nerd Font Mono` for several icons. On startup it checks whether the font is installed and logs a warning if it is missing.

You can inspect installed fonts in Font Book, or from the terminal:

```bash
system_profiler SPFontsDataType | grep -B2 -A4 "Symbols Nerd Font Mono"
```

If the font is missing, install Nerd Fonts and restart EasyBar. If the font is installed after EasyBar already started, restart the app and agents so the font check and layout run again.

#### Calendar widget is empty

Make sure the calendar agent is running:

```bash
brew services list | grep easybar-calendar-agent
pgrep -fl easybar-calendar-agent
```

Then grant Calendar access in macOS settings. EasyBar exposes menu actions to open the relevant settings pages, and the calendar agent permission state is shown in the bar context menu.

If you changed permissions and nothing updates, restart the calendar agent and EasyBar:

```bash
brew services restart gi8lino/tap/easybar-calendar-agent
brew services restart gi8lino/tap/easybar
```

#### Wi-Fi or network widget is empty

Make sure the network agent is running:

```bash
brew services list | grep easybar-network-agent
pgrep -fl easybar-network-agent
```

The network agent depends on Location Services permission. If permission is denied or unresolved, Wi-Fi-specific fields may be unavailable by design.

Restart the network agent after changing permission settings:

```bash
brew services restart gi8lino/tap/easybar-network-agent
brew services restart gi8lino/tap/easybar
```

#### AeroSpace mode widget does not update

If your AeroSpace mode widget does not change after switching layouts, make sure your AeroSpace bindings call:

```bash
easybar --space-mode-changed
```

For example, after every `layout ...` command in your AeroSpace config, add an `exec-and-forget` call to EasyBar. Without that trigger, EasyBar may not know that the layout mode changed yet.

#### Config changes do not apply

If `watch_config = false`, EasyBar will not automatically reload config changes. Either enable config watching or reload manually:

```bash
easybar --reload-config
```

If a reload is rejected, EasyBar keeps the last valid config and logs the parse or validation error. Check the logs instead of assuming the new file was accepted.

#### Lua widgets stop updating

Restart the Lua runtime:

```bash
easybar --refresh
```

or use the bar context menu item:

- `Restart Lua Runtime`

If that is not enough, restart the app:

```bash
brew services restart gi8lino/tap/easybar
```

If a widget still fails, check your configured `widgets_dir`, Lua path, and any widget-specific logs or output.

### Reset and recover

A good recovery sequence is:

```bash
brew services stop gi8lino/tap/easybar
brew services stop gi8lino/tap/easybar-calendar-agent
brew services stop gi8lino/tap/easybar-network-agent

pkill -x EasyBar || true
pkill -x easybar-calendar-agent || true
pkill -x easybar-network-agent || true

brew services start gi8lino/tap/easybar-calendar-agent
brew services start gi8lino/tap/easybar-network-agent
brew services start gi8lino/tap/easybar
```

That clears the usual problems caused by duplicate instances, stale agent state, or mixed manual and service launches.

## Packages and targets

EasyBar is split into a few Swift packages/targets:

- `EasyBarShared`
  shared models, config loading, IPC types, and common utilities
- `EasyBar`
  the main macOS status bar app
- `EasyBarCtl`
  the `easybar` command-line client for talking to the control socket
- `EasyBarCalendarAgent`
  helper app that owns EventKit and calendar snapshots
- `EasyBarNetworkAgent`
  helper app that owns Wi-Fi and network observation
- `EasyBarNetworkAgentCore`
  shared network-agent implementation used by EasyBarNetworkAgent and also reused by the standalone wifi-snitch project

For implementation details, see the docs in [`docs/`](./docs/).

## Docs

- [docs/CONFIG.md](./docs/CONFIG.md)
  config structure, native groups, and box-model rules
- [docs/AGENTS.md](./docs/AGENTS.md)
  calendar and network agents, permissions, and how EasyBar uses them
- [docs/LUA_WIDGETS.md](./docs/LUA_WIDGETS.md)
  Lua widget authoring and interaction model

## License

This project is licensed under the Apache 2.0 License. See the [LICENSE](LICENSE) file for details.

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
- AeroSpace integration for spaces and focused app state
- Event-driven updates and interactive popups
- Calendar and network helper agents for permission-sensitive data
- Homebrew install and service workflow

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
xattr -d com.apple.quarantine "$(command -v easybarctl)"
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

More details live in [docs/AGENTS.md](/Users/qiwi/code/easybar/docs/AGENTS.md).

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

[builtins.groups.system]
position = "right"
order = 20

[builtins.groups.system.style]

[builtins.battery]
enabled = true
group = "system"

[builtins.wifi]
enabled = true
group = "system"

[builtins.calendar]
enabled = true
```

The repository includes two config examples:

- [config.defaults.toml](/Users/qiwi/code/easybar/config.defaults.toml)
  full reference file with the current defaults and supported sections
- [config.minimal.toml](/Users/qiwi/code/easybar/config.minimal.toml)
  smaller starter example with a native `system` group

Config details, native groups, and example layouts are documented in [docs/CONFIG.md](/Users/qiwi/code/easybar/docs/CONFIG.md).

## Docs

- [docs/CONFIG.md](/Users/qiwi/code/easybar/docs/CONFIG.md)
  config structure, native groups, and box-model rules
- [docs/AGENTS.md](/Users/qiwi/code/easybar/docs/AGENTS.md)
  calendar and network agents, permissions, and how EasyBar uses them
- [docs/LUA_WIDGETS.md](/Users/qiwi/code/easybar/docs/LUA_WIDGETS.md)
  Lua widget authoring and interaction model

## License

This project is licensed under the Apache 2.0 License. See the [LICENSE](LICENSE) file for details.

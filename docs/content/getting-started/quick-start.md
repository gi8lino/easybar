# Quick Start

This is the shortest path from a fresh install to a working EasyBar setup.

The goal is to keep first-run setup user-facing: install the app, copy a small config, start the services, verify the bar, then decide whether to configure built-ins or add Lua widgets.

## 1. Install EasyBar

Add the Homebrew tap and install EasyBar:

```bash
brew tap gi8lino/tap
brew install gi8lino/tap/easybar
```

This also installs the calendar and network helper agents.

## 2. Copy a minimal config

Create the config directory and copy the starter config:

```bash
mkdir -p ~/.config/easybar
cp config.minimal.toml ~/.config/easybar/config.toml
```

The minimal config enables common built-ins and one native system group. It is a better starting point than the full defaults file when you only want the bar running quickly.

## 3. Start EasyBar and its agents

Start the helper agents first, then the main bar service:

```bash
brew services start gi8lino/tap/easybar-calendar-agent
brew services start gi8lino/tap/easybar-network-agent
brew services start gi8lino/tap/easybar
```

The agents provide permission-sensitive calendar and network data. EasyBar can still start when an agent has no permission, but the related widget may show empty or denied data until macOS permissions are granted.

## 4. Verify the install

Check services:

```bash
brew services list | grep easybar
```

Check running processes:

```bash
pgrep -fl EasyBar
pgrep -fl easybar-calendar-agent
pgrep -fl easybar-network-agent
```

Trigger one refresh:

```bash
easybar --refresh
```

If the bar does not appear, open [Troubleshooting](../runtime/troubleshooting.md). If macOS blocks the app or helper agents, open [macOS Quarantine](macos-quarantine.md).

## 5. Enable built-ins first

For most setups, start by configuring native built-ins in `~/.config/easybar/config.toml`.

Good first built-ins are:

- spaces
- battery
- Wi-Fi
- calendar
- time
- date
- volume
- front app

Example:

```toml
[builtins.time]
enabled = true

[builtins.date]
enabled = true

[builtins.battery]
enabled = true
```

Reload config after editing:

```bash
easybar --reload-config
```

Use [Built-ins](../configuration/builtins.md) for built-in widget behavior and [Native Groups](../configuration/native-groups.md) when several widgets should share one visual container.

## 6. Add Lua only when you need custom behavior

Use Lua when you need custom text, shell commands, project-specific status, custom click behavior, or popup content that is not already covered by a built-in.

Create the widget directory if needed:

```bash
mkdir -p ~/.config/easybar/widgets
```

Then follow [First Widget](../lua/guides/first-widget.md).

## 7. Keep deeper docs separate

The first-run path should not require architecture docs, process model docs, generated reference pages, or Lua runtime internals.

Use these only when needed:

- [Configuration Reference](../configuration/reference.md) for exact config keys and defaults.
- [Lua Reference](../lua/reference/index.md) for exact Lua API shapes.
- [Internals](../internals/overview.md) for contributors, architecture, agents, process boundaries, and runtime implementation details.

# Quick Start

This is the shortest path from a fresh install to a working EasyBar setup.

EasyBar can start without a custom config. The built-in defaults already show a useful bar with spaces, battery, Wi-Fi, and calendar enabled. Create `config.toml` only when you want to customize the bar.

## 1. Install EasyBar

Add the Homebrew tap and install EasyBar:

```bash
brew tap gi8lino/tap
brew install --cask gi8lino/tap/easybar
```

The self-contained app includes both helper agents and supervises them itself.

## 2. Start EasyBar

Open the app from Finder, Spotlight, or the command line:

```bash
open -a EasyBar
```

The agents provide permission-sensitive calendar and network data. EasyBar can still start when an agent has no permission, but the related widget may show empty or denied data until macOS permissions are granted.

EasyBar also shows a controller icon in the macOS menu bar. Use it to stop or restart the bar, reload configuration, restart helper agents, and open EasyBar directories. The icon remains available if you stop only the bar runtime.

## 3. Verify the install

Check the installed application:

```bash
test -d /Applications/EasyBar.app && echo "EasyBar is installed"
```

Check running processes:

```bash
pgrep -fl EasyBar
pgrep -fl EasyBarCalendarAgent
pgrep -fl EasyBarNetworkAgent
```

Trigger one refresh:

```bash
easybar --refresh
```

If the bar does not appear, open [Troubleshooting](../runtime/troubleshooting.md). If macOS blocks the app or helper agents, open [macOS Quarantine](macos-quarantine.md).

## 4. Optional: create a custom config

EasyBar reads custom config from:

```text
~/.config/easybar/config.toml
```

The repository includes `config.minimal.toml` as a small starter override. It keeps the default built-ins enabled, groups battery and Wi-Fi, and opens Wi-Fi in details mode.

From a cloned repository:

```bash
mkdir -p ~/.config/easybar
cp config.minimal.toml ~/.config/easybar/config.toml
easybar --reload-config
```

Use [Example Configs](../configuration/example-configs.md) for the available starter files.

## 5. Customize built-ins first

For most setups, customize native built-ins in `~/.config/easybar/config.toml` before writing Lua.

The default bar already enables:

- spaces
- battery
- Wi-Fi
- calendar

Good next built-ins to enable are:

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

[builtins.volume]
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

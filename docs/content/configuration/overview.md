# Configuration Overview

EasyBar reads its runtime config from:

```text
~/.config/easybar/config.toml
```

You can override that path with:

```bash
EASYBAR_CONFIG_PATH=/path/to/config.toml
```

## Example files

The repository ships two config examples:

- `config.defaults.toml`
  Full reference file with the current default values and supported sections.
- `config.minimal.toml`
  Smaller starter example with common built-ins and one native `system` group.

Use `config.defaults.toml` when you want the complete reference.
Use `config.minimal.toml` when you want a shorter starting point.

If you are unsure whether a widget belongs in config or in a Lua file, read [Built-ins Vs Lua](../getting-started/builtins-vs-lua.md).

## Important sections

- `[app]`
  App-level paths and runtime behavior.
- `[app.env]`
  Environment variables visible to Lua widgets and widget shell commands.
- `[theme]`
  Selected theme name and custom theme directory.
- `[theme.colors]`
  Optional theme color token overrides.
- `[logging]`
  Shared logging config for EasyBar and helper agents.
- `[agents.calendar]`
  Calendar helper agent settings.
- `[agents.network]`
  Network helper agent settings.
- `[bar]`
  Bar height, padding, and top-edge behavior.
- `[bar.colors]`
  Bar background and border colors.
- `[builtins.*]`
  Native built-in widget configuration.
- `[builtins.groups.*]`
  Native widget groups.

## Theme and override model

Themes provide shared visual defaults.

Explicit config values still win.

The practical order is:

```text
built-in app defaults
→ selected theme
→ [theme.colors] overrides
→ explicit [bar] and [builtins.*] values
→ Lua widget props
```

That means a theme can set the default palette, while a specific widget can still use exact colors.

Example:

```toml
[theme]
name = "mocha"
themes_dir = "~/.config/easybar/themes"

[theme.colors]
accent = "#8aadf4"

[bar.colors]
background = "#090909"
```

See [Themes](themes.md).

## When configuration is enough

Stay in `config.toml` when EasyBar already provides the widget you need as a built-in and you mainly want to control placement, grouping, theming, or styling.

Move to Lua when you need custom interaction, shell-command integration, or custom event-driven behavior.

See [Built-ins Vs Lua](../getting-started/builtins-vs-lua.md) and [Lua Widgets](../lua/overview.md).

## Related pages

- [Themes](themes.md)
- [Built-ins](builtins.md)
- [Native Groups](native-groups.md)
- [Box Model](box-model.md)
- [Environment](environment.md)
- [Logging](logging.md)

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
  Smaller starter example with `spaces`, `battery`, `wifi`, `calendar`, and one native `system` group.

Use `config.defaults.toml` when you want the complete reference.
Use `config.minimal.toml` when you want a shorter starting point.

If you are unsure whether a widget belongs in config or in a Lua file, read [Built-ins Vs Lua](../getting-started/builtins-vs-lua.md).

## Important sections

- `[app]`
  App-level paths and runtime behavior.
- `[app.env]`
  Environment variables visible to Lua widgets and widget shell commands.
- `[logging]`
  Shared logging config for EasyBar and helper agents.
- `[agents.calendar]`
  Calendar helper agent settings.
- `[agents.network]`
  Network helper agent settings.
- `[builtins.*]`
  Native built-in widget configuration.
- `[builtins.groups.*]`
  Native widget groups.

## When configuration is enough

Stay in `config.toml` when EasyBar already provides the widget you need as a built-in and you mainly want to control placement, grouping, or styling.

Move to Lua when you need custom interaction, shell-command integration, or custom event-driven behavior.

See [Built-ins Vs Lua](../getting-started/builtins-vs-lua.md) and [Lua Widgets](../lua/overview.md).

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

## Pages

- [App Settings](app.md)
- [Environment](environment.md)
- [Logging](logging.md)
- [Agents](agents.md)
- [Built-ins](builtins.md)
- [Native Groups](native-groups.md)
- [Box Model](box-model.md)
- [Developer Menu](developer-menu.md)
- [Example Configs](example-configs.md)

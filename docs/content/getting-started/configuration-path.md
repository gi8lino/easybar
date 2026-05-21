# Config Path

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

## Related pages

- [Configuration Overview](../configuration/overview.md)
- [App Settings](../configuration/app.md)
- [Environment](../configuration/environment.md)
- [Example Configs](../configuration/example-configs.md)

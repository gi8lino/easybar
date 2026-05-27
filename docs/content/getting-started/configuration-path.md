# Config Path

EasyBar reads its runtime config from:

```text
~/.config/easybar/config.toml
```

You can override that path with:

```bash
EASYBAR_CONFIG_PATH=/path/to/config.toml
```

## Theme path

Custom themes are loaded from the directory configured in `config.toml`:

```toml
[theme]
themes_dir = "~/.config/easybar/themes"
```

By default, this is usually next to your config file:

```text
~/.config/easybar/themes
```

Theme files use the theme name plus `.toml`.

Example:

```text
~/.config/easybar/themes/my-theme.toml
```

Then select it with:

```toml
[theme]
name = "my-theme"
```

Bundled themes are shipped inside the app bundle and are used when no matching custom theme exists in `themes_dir`.

## Example files

The repository ships two config examples:

- `config.defaults.toml`
  Full reference file with the current default values and supported sections.
- `config.minimal.toml`
  Smaller starter example with common built-ins and one native `system` group.

Use `config.defaults.toml` when you want the complete reference.
Use `config.minimal.toml` when you want a shorter starting point.

## Related pages

- [Configuration Overview](../configuration/overview.md)
- [Themes](../configuration/themes.md)
- [App Settings](../configuration/app.md)
- [Environment](../configuration/environment.md)
- [Example Configs](../configuration/example-configs.md)

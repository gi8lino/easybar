# Example Configs

The repository includes two config examples:

- `config.defaults.toml`
- `config.minimal.toml`

## `config.defaults.toml`

Use this when you want the complete reference file with current defaults and supported sections.

It is useful for:

- discovering all available keys
- checking default values
- seeing all supported built-ins
- checking theme configuration
- comparing your local config against the project defaults

The defaults file includes the theme section:

```toml
[theme]
name = "default"
themes_dir = "~/.config/easybar/themes"
```

## `config.minimal.toml`

Use this when you want a smaller starting point.

It includes a compact setup with common built-ins such as:

- spaces
- battery
- Wi-Fi
- calendar
- one native `system` group

It should also include only the theme settings needed to select a theme.

Example:

```toml
[theme]
name = "mocha"
themes_dir = "~/.config/easybar/themes"
```

## Copy a starter config

Example:

```bash
mkdir -p ~/.config/easybar
cp config.minimal.toml ~/.config/easybar/config.toml
```

Then reload EasyBar:

```bash
easybar --reload-config
```

## Add a custom theme

Create a custom theme directory:

```bash
mkdir -p ~/.config/easybar/themes
```

Add a custom theme file:

```text
~/.config/easybar/themes/my-theme.toml
```

Then select it in `config.toml`:

```toml
[theme]
name = "my-theme"
themes_dir = "~/.config/easybar/themes"
```

See [Themes](themes.md) for the theme file format.

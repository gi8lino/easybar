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
- comparing your local config against the project defaults

## `config.minimal.toml`

Use this when you want a smaller starting point.

It includes a compact setup with common built-ins such as:

- spaces
- battery
- Wi-Fi
- calendar
- one native `system` group

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

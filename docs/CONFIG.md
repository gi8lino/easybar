# EasyBar config

EasyBar reads its runtime config from:

```text
~/.config/easybar/config.toml
```

You can override that path with:

```bash
EASYBAR_CONFIG_PATH=/path/to/config.toml
```

## Repo config files

This repository ships two config examples:

- `./config.defaults.toml`
  full reference file with the current default values and supported sections
- `./config.minimal.toml`
  smaller starter example with `spaces`, `battery`, `wifi`, `calendar`, and one native `system` group

Use `config.defaults.toml` when you want the complete reference.
Use `config.minimal.toml` when you want a shorter starting point.

## Native groups

EasyBar supports native built-in groups in `config.toml`.

Groups let multiple native built-ins share:

- one background
- one border
- one padding box
- one spacing rule

Example:

```toml
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
```

Notes:

- groups are not created by default
- built-ins are not attached to a group by default
- if you use `group = "system"`, the referenced group must exist under `[builtins.groups.system]`

## Box model

Built-in widgets and native groups use the same shared box-model keys:

- `margin_x`
- `margin_y`
- `padding_x`
- `padding_y`
- `spacing`

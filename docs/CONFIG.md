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

## Logging

EasyBar uses one shared log directory for all three processes:

- `easybar.out`
- `calendar-agent.out`
- `network-agent.out`

Configure that directory with:

```toml
[logging]
directory = "~/.local/state/easybar"
```

## Agents

Both helper agents are enabled by default.

You can turn them off independently with:

```toml
[agents.calendar]
enabled = true

[agents.network]
enabled = true
allow_unauthorized_non_sensitive_fields = false
```

When an agent is disabled, its helper app exits without opening its socket.

For the network agent:

- `allow_unauthorized_non_sensitive_fields = false`
  Wi-Fi field requests fail while location permission is denied
- `allow_unauthorized_non_sensitive_fields = true`
  non-Wi-Fi fields may still be returned without location access

Other common network-agent config:

```toml
[agents.network]
enabled = true
socket_path = "/tmp/EasyBar/network-agent.sock"
refresh_interval_seconds = 60
allow_unauthorized_non_sensitive_fields = false
```

Calendar-agent socket config:

```toml
[agents.calendar]
enabled = true
socket_path = "/tmp/EasyBar/calendar-agent.sock"
```

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
order = 40

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

For the native `spaces` widget:

- `[builtins.spaces]` controls the outer container placement and shared box model
- `[builtins.spaces.layout]` controls the internal workspace-pill layout

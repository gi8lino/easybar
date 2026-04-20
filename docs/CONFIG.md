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

## App environment

Use `[app.env]` for environment variables that should be visible inside the Lua runtime and any shell commands launched by widgets.

Example:

```toml
[app]
widgets_dir = "~/.config/easybar/widgets"
lua_path = "/opt/homebrew/bin/lua"

[app.env]
PATH = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
TAILSCALE = "/usr/local/bin/tailscale"
```

Behavior:

- if `[app.env]` sets `PATH`, EasyBar passes that exact value to the Lua runtime
- if `[app.env]` does not set `PATH`, EasyBar uses the inherited app `PATH` when available
- if the app itself has no usable `PATH`, EasyBar falls back to `/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin`

This is especially useful for GUI-launched EasyBar sessions on macOS, where shell startup files such as `.zshrc` are not used to populate the app environment.

## Logging

EasyBar uses one shared log directory for all three processes:

- `easybar.out`
- `calendar-agent.out`
- `network-agent.out`

Configure logging with:

```toml
[logging]
enabled = true
level = "info"
directory = "~/.local/state/easybar"
```

Supported levels:

- `trace`
- `debug`
- `info`
- `warn`
- `error`

Meaning:

- `trace`
  info, debug, warnings, errors, and very verbose trace logs
- `debug`
  info plus debug logs
- `info`
  normal runtime logs
- `warn`
  warnings and errors only
- `error`
  error logs only

Notes:

- the main app and helper agents now use this config-driven level instead of legacy `EASYBAR_DEBUG` / `EASYBAR_TRACE` environment toggles
- `EASYBAR_CONFIG_PATH` remains the main environment override for the runtime config file
- the `easybar` CLI may still support its own debug flag or CLI-only debug env handling, but that is separate from app and agent runtime logging

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

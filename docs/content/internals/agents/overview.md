# Agents Overview

EasyBar uses two helper processes:

- `easybar-calendar-agent`
- `easybar-network-agent`

Both run out of process, listen on a local Unix socket, and exchange newline-delimited JSON messages with clients.

The main client is EasyBar itself, but the network agent protocol is also reused by standalone clients such as `wifi-snitch`.

## Why agents exist

The agents keep permission-sensitive system APIs out of the main UI process.

EasyBar stays focused on:

- rendering the bar
- managing widgets
- consuming agent data and building UI state

The agents stay focused on:

- permission ownership
- system observation
- raw data collection
- socket delivery

The important boundary is:

- agents collect and return data
- EasyBar decides how that data is rendered

For example, the network agent returns RSSI, while EasyBar maps RSSI into Wi-Fi bars.

## Runtime config

Both agents load the shared runtime config from:

- `EASYBAR_CONFIG_PATH`, when set
- otherwise `~/.config/easybar/config.toml`

Relevant config:

```toml
[app]
runtime_dir = "~/.local/state/easybar/runtime"

[logging]
enabled = false
level = "info"
directory = "~/.local/state/easybar"

[agents.calendar]
enabled = true

[agents.network]
enabled = true
refresh_interval_seconds = 60
allow_unauthorized_non_sensitive_fields = false
```

The agent socket paths are derived from `app.runtime_dir` unless their individual `socket_path` settings are overridden. `EASYBAR_RUNTIME_DIR` overrides `app.runtime_dir` for the app, CLI, and both agents.

If an agent is disabled in config, the helper app exits immediately without opening its socket.

## Services

In the Homebrew setup:

```bash
brew services start gi8lino/tap/easybar-calendar-agent
brew services start gi8lino/tap/easybar-network-agent
```

EasyBar connects to them over Unix sockets.

# Agents

EasyBar uses two helper agents:

- `easybar-calendar-agent`
- `easybar-network-agent`

Both helper agents are enabled by default.

## Calendar agent

```toml
[agents.calendar]
enabled = true
socket_path = "/tmp/EasyBar/calendar-agent.sock"
```

The calendar agent owns EventKit access, calendar permission handling, event snapshots, and event mutations.

## Network agent

```toml
[agents.network]
enabled = true
socket_path = "/tmp/EasyBar/network-agent.sock"
refresh_interval_seconds = 60
allow_unauthorized_non_sensitive_fields = false
```

The network agent owns Wi-Fi and network observation.

## Disable an agent

```toml
[agents.calendar]
enabled = false

[agents.network]
enabled = false
```

When an agent is disabled, its helper app exits immediately without opening its socket.

## Network permission behavior

```toml
[agents.network]
allow_unauthorized_non_sensitive_fields = false
```

When this is `false`, Wi-Fi field requests fail while location permission is denied.

When this is `true`, non-Wi-Fi fields may still be returned without location access.

The default is privacy-first: requests for Wi-Fi fields fail until location access is granted.

## Troubleshooting

For agent process checks, socket probes, permission issues, raw field inspection, and Homebrew service logs, use [Debugging Agents](../internals/agents/debugging.md).

## More detail

See the internal agent docs:

- [Agents Overview](../internals/agents/overview.md)
- [Calendar Agent](../internals/agents/calendar-agent.md)
- [Network Agent](../internals/agents/network-agent.md)
- [Debugging Agents](../internals/agents/debugging.md)

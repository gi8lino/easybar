# CLI

The `EasyBarCtl` target builds the `easybar` executable.

It is a thin client for the app and agent control sockets, plus a read-only viewer for shared process logs.

## Responsibilities

The CLI translates user commands into socket requests.

Its job is to:

- translate CLI flags into typed control commands
- connect to the EasyBar Unix socket
- send JSON requests
- decode typed JSON responses
- report success or failure to the shell
- merge, filter, and follow retained app and agent logs through `EasyBarShared`

This keeps automation simple and avoids forcing users to speak the socket protocol manually.

## Common commands

Typical examples:

```bash
easybar --refresh
easybar --restart-lua-runtime
easybar --reload-config
easybar --restart-calendar-agent
easybar --restart-network-agent
easybar --restart-agents
easybar --event workspace_change
easybar logs --widget tailscale --since 30m
```

## Design rule

The CLI should stay small.

Most commands use the main EasyBar control socket. Agent restart commands contact the calendar or network socket directly through the shared agent protocol. `easybar logs` instead reads the configured log directory and follows active files by file identity so rename-based rotation does not interrupt the stream.

It is a transport client, not a second source of application logic.

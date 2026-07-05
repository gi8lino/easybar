# CLI

The `EasyBarCtl` target builds the `easybar` executable.

It is a thin client for the main app control socket.

## Responsibilities

The CLI translates user commands into socket requests.

Its job is to:

- translate CLI flags into typed control commands
- connect to the EasyBar Unix socket
- send JSON requests
- decode typed JSON responses
- report success or failure to the shell

This keeps automation simple and avoids forcing users to speak the socket protocol manually.

## Common commands

Typical examples:

```bash
easybar --refresh
easybar --restart-lua-runtime
easybar --reload-config
easybar --event workspace_change
```

## Design rule

The CLI should stay small.

It is a transport client, not a second source of application logic.

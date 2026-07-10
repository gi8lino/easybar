# Agent Protocol

Both agents share the same transport and baseline command flow.

## Socket paths

By default, agent sockets are derived from `[app].runtime_dir`:

- calendar agent: `<runtime_dir>/calendar-agent.sock`
- network agent: `<runtime_dir>/network-agent.sock`

The default runtime directory is `~/.local/state/easybar/runtime`. `EASYBAR_RUNTIME_DIR` can override it for all EasyBar processes.

EasyBar connects to those sockets directly.

Other local clients can also connect when they speak the same protocol.

## Transport format

- newline-delimited JSON
- one request per line
- one response per line

Example:

```json
{ "command": "ping" }
```

## Common commands

Common commands include:

- `ping`
- `version`
- `fetch`
- `subscribe`

`version` returns the running binary version and the shared EasyBar IPC protocol version:

```json
{
  "kind": "version",
  "version": {
    "appVersion": "0.4.0",
    "protocolVersion": "1"
  }
}
```

`appVersion` identifies the installed EasyBar build. `protocolVersion` identifies the internal JSON socket contract shared by the app and helper agents.

The calendar agent additionally supports:

- `create_event`
- `update_event`
- `delete_event`

Every response includes a `kind` field.

Common kinds include:

- `pong`
- `version`
- `subscribed`
- `error`

## Typical behavior

- `ping`
  returns one `pong`, then closes
- `version`
  returns one version payload, then closes
- `fetch`
  returns one data payload, then closes
- `subscribe`
  returns one `subscribed`, returns one immediate data payload, then keeps the socket open for later pushes

## EasyBar command behavior

EasyBar keeps long-lived subscriptions open to the agents for normal runtime updates.

A manual refresh:

```bash
easybar --refresh
```

- does not reload config
- does not restart agents
- triggers fresh reads and UI updates

A Lua restart:

```bash
easybar --restart-lua-runtime
```

- restarts only Lua
- does not restart agents

A config reload:

```bash
easybar --reload-config
```

- reloads `config.toml`
- rebuilds runtime state
- recreates agent-backed subscriptions



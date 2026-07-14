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
- `restart`

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
- `restarting`
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
- `restart`
  returns one `restarting` acknowledgement, closes the request socket, then exits the agent process cleanly

## Agent restart flow

Both the calendar and network agents accept the following one-shot request:

```json
{ "command": "restart" }
```

The agent confirms that it accepted the request before terminating:

```json
{ "kind": "restarting" }
```

The full restart sequence is:

1. The client sends `restart` over the agent's Unix socket.
2. The agent sends `restarting` so the client knows the request was accepted.
3. The agent exits through its normal AppKit shutdown path.
4. The service supervisor starts a fresh agent process.
5. EasyBar reconnects when the agent socket becomes available again.

The packaged `EasyBar.app` supervises its nested agents and relaunches them after the acknowledged exit. Legacy Homebrew-service installations use `launchd` with `keep_alive` for the same behavior. A manually launched standalone agent has no supervisor and therefore stays stopped after it exits.

Restart is available only while the agent socket is responsive. If the agent has already crashed or cannot answer requests, its service supervisor remains responsible for recovery.

The CLI exposes this operation as `--restart-calendar-agent`, `--restart-network-agent`, and `--restart-agents`. The combined command attempts both agents before reporting a partial failure with a nonzero exit status.

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

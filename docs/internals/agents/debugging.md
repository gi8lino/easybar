# Debugging Agents

When something does not work, debugging agents is usually the fastest way to find the issue.

## 1. Check processes

```bash
pgrep -fl easybar-calendar-agent
pgrep -fl easybar-network-agent
```

If nothing shows up:

```bash
brew services start gi8lino/tap/easybar-calendar-agent
brew services start gi8lino/tap/easybar-network-agent
```

## 2. Check logs

If logging is enabled:

```toml
[logging]
enabled = true
level = "debug"
```

Logs are written to:

```text
~/.local/state/easybar/
```

Or via Homebrew:

```bash
tail -n 200 ~/Library/Logs/Homebrew/easybar-calendar-agent/*.log
tail -n 200 ~/Library/Logs/Homebrew/easybar-network-agent/*.log
```

For extremely verbose socket and update tracing, temporarily use:

```toml
[logging]
enabled = true
level = "trace"
```

## 3. Test socket manually

You can talk to agents directly.

Ping the network agent:

```bash
echo '{"command":"ping"}' | nc -U /tmp/EasyBar/network-agent.sock
```

Expected response:

```json
{ "kind": "pong" }
```

Fetch fields:

```bash
echo '{"command":"fetch","fields":["wifi.ssid"]}' | nc -U /tmp/EasyBar/network-agent.sock
```

## 4. Common problems

### No data returned

- agent not running
- wrong socket path
- config disabled agent

### Wi-Fi fields missing

- Location permission not granted
- check macOS Location Services settings

```bash
systemsettings Privacy LocationServices
```

### Calendar empty

- Calendar permission not granted
- EventKit access denied

### Permission stuck at `not_determined`

Agents retry with backoff:

```text
1, 2, 3, 5, 8, 13, ... seconds
```

Wait or restart the agent.

### Wrong or stale data

Restart agents:

```bash
brew services restart gi8lino/tap/easybar-network-agent
brew services restart gi8lino/tap/easybar-calendar-agent
```

## Debugging Lua vs Agent

| Problem | Likely source |
| --- | --- |
| No socket response | agent |
| JSON correct but widget wrong | Lua |
| Event missing field | EasyBar mapping |

## Inspect raw agent output

Useful for debugging mapping issues:

```bash
echo '{"command":"fetch","fields":["wifi.ssid","network.primary_interface_is_tunnel"]}' \
  | nc -U /tmp/EasyBar/network-agent.sock
```

Compare:

- raw agent fields
- Lua event tables such as `event.network`

## Debugging strategy

Best order:

1. agent: working?
2. socket: returning data?
3. EasyBar: mapping correctly?
4. Lua: using correct fields?

Always debug from the bottom up:

```text
Agent → Socket → EasyBar → Lua → UI
```

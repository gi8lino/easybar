# CLI Reference

The `easybar` command controls the running app, validates configuration, restarts helper agents, and exposes diagnostics. Most commands contact a Unix-domain socket, so the relevant process must be running. The `logs` command reads the configured process log directory directly and does not require a control socket.

## Runtime commands

| Command                         | Purpose                                                                       |
| ------------------------------- | ----------------------------------------------------------------------------- |
| `easybar --refresh`             | Refresh the bar, widgets, and agent-backed data without reloading config.     |
| `easybar --reload-config`       | Read `config.toml` again and rebuild the current bar.                         |
| `easybar --restart-lua-runtime` | Restart only the Lua widget runtime using the currently loaded configuration. |
| `easybar --metrics`             | Print one runtime metrics snapshot.                                           |
| `easybar --metrics --watch`     | Continuously display runtime metrics and rolling graphs.                      |
| `easybar logs`                  | Show recent retained logs, then follow new app and agent entries.             |

See [Runtime Control](control.md) for the difference between refresh, reload, and restart operations. See [Metrics](metrics.md) for the fields included in a snapshot.

## Inbox commands

Local scripts can publish structured notifications directly to the native inbox:

```bash
easybar inbox send \
  --source backup \
  --severity error \
  --title "Backup failed" \
  --message "The nightly MinIO backup failed after 3 attempts." \
  --group "backup:minio" \
  --url "https://grafana.example.com/backup-logs"
```

`--source` and `--title` are required. Severity defaults to `info` and accepts `info`, `success`,
`warning`, or `error`. `--group` supplies the inbox category used by category grouping. An HTTP(S)
`--url` adds an **Open** action to the message. New messages are unread unless `--read` is supplied.

By default, `send` generates a unique message ID. Use `--id` when a recurring script should update
the same notification instead of creating another one:

```bash
easybar inbox send --source backup --id minio-nightly \
  --severity success --title "Backup completed"
```

Read the currently visible messages in human-readable or JSON form:

```bash
easybar inbox read
easybar inbox read --source backup --unread
easybar inbox read --json
```

`read` queries the inbox without changing message state. Use the explicit mutation commands to
change it:

```bash
easybar inbox mark-read --source backup --id minio-nightly
easybar inbox mark-unread --source backup --id minio-nightly
easybar inbox dismiss --source backup --id minio-nightly
easybar inbox remove --source backup --id minio-nightly
easybar inbox clear --source backup
easybar inbox clear --all
```

Omitting `--id` from `mark-read`, `mark-unread`, or `dismiss` applies the operation to every visible
message from the selected source. `remove` requires both `--source` and `--id` and deletes that
message plus its saved local state. A Lua publisher can recreate a removed item in a later snapshot;
use `dismiss` when it should remain suppressed across publisher refreshes. `clear --all` is required
to remove every source, preventing an unscoped clear by accident. `add` is an alias for `send`, and
`list` is an alias for `read`.

CLI-published message content follows the same lifecycle as Lua-published snapshots: it remains in
memory until cleared or until EasyBar restarts. Local read, unread, and dismissed state is persisted
for stable source/ID pairs. See [Native Inbox](../lua/guides/inbox.md) for the complete inbox model.

## Logs

`easybar logs` merges the main app, calendar-agent, and network-agent logs in timestamp order. It prints the latest 100 matching entries and then follows all three active files across log rotation. Each plain-text line is prefixed with its source process.

```bash
easybar logs
easybar logs --widget tailscale --runtime lua --level debug
easybar logs --runtime native --since 30m
easybar logs --request-id lua-19
```

`--request-id` and `--since` search all matching retained history by default. Use `--lines` to limit that history explicitly. Request-correlated entries also carry a `run_id`, which distinguishes repeated request IDs from different EasyBar process runs.

| Option                | Purpose                                                                     |
| --------------------- | --------------------------------------------------------------------------- |
| `--widget NAME`       | Match a Lua or native widget name.                                          |
| `--runtime KIND`      | Match `lua`, `native`, or `agent`.                                          |
| `--level LEVEL`       | Match the selected severity and higher.                                     |
| `--request-id ID`     | Match one request across every retained process log.                        |
| `--since TIME`        | Match entries since `30s`, `15m`, `2h`, `1d`, `1w`, or an ISO-8601 time.    |
| `--lines COUNT`, `-n` | Limit the matching history printed before live following starts.            |
| `--all`               | Print all matching retained history.                                        |
| `--no-follow`         | Exit after history; useful for scripts, issue reports, and shell pipelines. |
| `--json`              | Emit JSON Lines with parsed fields, source, runtime, and widget metadata.   |

Filters compose. For example, this prints errors from the Lua runtime during the last hour and exits:

```bash
easybar logs --runtime lua --level error --since 1h --no-follow
```

History is limited to the active files and numbered archives retained by EasyBar's rotation policy. `--all` means all retained history, not logs that have already rotated out.

## Helper-agent commands

| Command                            | Purpose                                            |
| ---------------------------------- | -------------------------------------------------- |
| `easybar --restart-calendar-agent` | Restart the calendar agent through its socket.     |
| `easybar --restart-network-agent`  | Restart the network agent through its socket.      |
| `easybar --restart-agents`         | Attempt both restarts and report partial failures. |

The agent acknowledges its restart request before exiting. Its Homebrew keep-alive service then launches it again. `--socket` can override one per-agent socket, but cannot be combined with `--restart-agents` because the agents use different sockets.

## Configuration validation

Validate the active configuration through the running app:

```bash
easybar --validate-config
```

Validate another file:

```bash
easybar --validate-config --config /path/to/config.toml
```

`EASYBAR_CONFIG_PATH` can select the file instead. A rejected live reload leaves the last valid configuration active.

## Scripting events

```bash
easybar --event workspace_change
easybar --event focus_change
easybar --event space_mode_change
```

Hyphens and underscores are accepted in event names. These commands emit driver events for Lua widgets and refresh the corresponding current state.

## General options

| Option                | Purpose                                                        |
| --------------------- | -------------------------------------------------------------- |
| `--socket PATH`, `-s` | Override the socket contacted by the selected operation.       |
| `--config PATH`       | Select a configuration file for `--validate-config`.           |
| `--debug`, `-d`       | Print CLI-side diagnostics; it does not change app log levels. |
| `--watch`, `-w`       | Keep streaming metrics; use with `--metrics`.                  |
| `--version`, `-v`     | Print the installed CLI version.                               |
| `--help`, `-h`        | Print command usage.                                           |

## Socket resolution failures

Without `--socket`, the CLI resolves control and helper-agent sockets from the same shared runtime
configuration used by EasyBar and its agents. A missing config file is valid and uses built-in
defaults. A present but malformed config is an error and is reported directly; the CLI no longer
silently falls back to a different default socket.

Use an explicit socket to diagnose or recover while the shared config is malformed:

```bash
easybar --refresh --socket ~/.local/state/easybar/runtime/easybar.sock
easybar --restart-calendar-agent --socket ~/.local/state/easybar/runtime/calendar-agent.sock
```

With `--debug`, the CLI reports whether each socket came from `--socket` or the shared config file.
`--restart-agents` cannot bypass config resolution because it needs two different agent sockets.

The CLI and running app versions should normally match after a Homebrew upgrade:

```bash
easybar --version
/Applications/EasyBar.app/Contents/MacOS/EasyBar --version
```

## Related pages

- [Runtime Control](control.md)
- [Metrics](metrics.md)
- [Logging](../configuration/logging.md)
- [Environment](../configuration/environment.md)
- [Control Socket Internals](../internals/architecture/control-socket.md)

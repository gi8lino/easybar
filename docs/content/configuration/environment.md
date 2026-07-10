# Environment

Use `[app.env]` for environment variables that should be visible inside the Lua runtime and any shell commands launched by widgets. EasyBar inherits the parent process environment and overlays these configured values.

## Example

```toml
[app]
widgets_dir = "~/.config/easybar/widgets"
lua_path = "lua"
runtime_dir = "~/.local/state/easybar/runtime"

[app.env]
PATH = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
TAILSCALE = "/usr/local/bin/tailscale"
```

## PATH behavior

EasyBar resolves `PATH` in this order:

1. If `[app.env]` sets `PATH`, EasyBar overlays that exact value onto the inherited process environment.
2. If `[app.env]` does not set `PATH`, EasyBar uses the default PATH shown below so GUI-launched sessions can still find common tools.

```text
/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
```

## EasyBar environment overrides

EasyBar supports a small, explicit set of process-level overrides:

| Variable              | Purpose                                      |
| --------------------- | -------------------------------------------- |
| `EASYBAR_CONFIG_PATH` | Selects the runtime config file.             |
| `EASYBAR_RUNTIME_DIR` | Overrides `[app].runtime_dir`.               |
| `EASYBAR_LOG_LEVEL`   | Temporarily overrides `[logging].level`.     |

`EASYBAR_RUNTIME_DIR` is read by the app, CLI, and helper agents. Derived socket and lock defaults therefore remain consistent across processes.

For the runtime directory, precedence is:

```text
EASYBAR_RUNTIME_DIR
→ app.runtime_dir
→ built-in default
```

Explicit `lua_socket_path`, `lock_dir`, or agent `socket_path` values still override their derived defaults.

EasyBar does not perform generic shell-style `$VARIABLE` expansion inside config values. Paths support `~` expansion only.

## Why this matters

GUI-launched macOS apps do not normally inherit your shell startup files such as `.zshrc`.

Set `[app.env]` when Lua widgets need tools such as:

- `brew`
- `tailscale`
- `kubectl`
- custom scripts
- package-manager commands

# Environment

Use `[app.env]` for environment variables that should be visible inside the Lua runtime and any shell commands launched by widgets. EasyBar inherits the parent process environment and overlays these configured values.

## Example

```toml
[app]
widgets_dir = "~/.config/easybar/widgets"
lua_path = "lua"
lua_socket_path = "/tmp/EasyBar/lua-runtime.sock"

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

## Why this matters

GUI-launched macOS apps do not normally inherit your shell startup files such as `.zshrc`.

Set `[app.env]` when Lua widgets need tools such as:

- `brew`
- `tailscale`
- `kubectl`
- custom scripts
- package-manager commands



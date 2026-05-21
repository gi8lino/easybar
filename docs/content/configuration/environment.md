# Environment

Use `[app.env]` for environment variables that should be visible inside the Lua runtime and any shell commands launched by widgets.

## Example

```toml
[app]
widgets_dir = "~/.config/easybar/widgets"
lua_path = "/opt/homebrew/bin/lua"
lua_socket_path = "/tmp/EasyBar/lua-runtime.sock"

[app.env]
PATH = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
TAILSCALE = "/usr/local/bin/tailscale"
```

## PATH behavior

EasyBar resolves `PATH` in this order:

1. If `[app.env]` sets `PATH`, EasyBar passes that exact value to the Lua runtime.
2. If `[app.env]` does not set `PATH`, EasyBar uses the inherited app `PATH` when available.
3. If the app itself has no usable `PATH`, EasyBar falls back to:

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

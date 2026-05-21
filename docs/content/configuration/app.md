# App Settings

The `[app]` section controls core EasyBar runtime behavior.

Example:

```toml
[app]
widgets_dir = "~/.config/easybar/widgets"
lua_path = "/opt/homebrew/bin/lua"
lua_socket_path = "/tmp/EasyBar/lua-runtime.sock"
```

## `widgets_dir`

The directory where EasyBar loads Lua widget files from.

```toml
[app]
widgets_dir = "~/.config/easybar/widgets"
```

Every `*.lua` file in this directory is loaded by the Lua runtime.

## `lua_path`

The Lua executable used for the Lua widget runtime.

```toml
[app]
lua_path = "/opt/homebrew/bin/lua"
```

## `lua_socket_path`

The dedicated Unix socket used between the main app and the Lua widget runtime.

```toml
[app]
lua_socket_path = "/tmp/EasyBar/lua-runtime.sock"
```

This socket is separate from stderr logs. Runtime protocol messages use JSON over the Lua socket.

## `develop`

The developer menu can be shown permanently with:

```toml
[app]
develop = true
```

By default, the developer section is hidden unless you hold `Shift` and right-click the bar.

See [Developer Menu](developer-menu.md).

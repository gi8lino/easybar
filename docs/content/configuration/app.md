# App Settings

The `[app]` section controls core EasyBar runtime behavior.

Example:

```toml
[app]
widgets_dir = "~/.config/easybar/widgets"
lua_path = "/opt/homebrew/bin/lua"
lua_socket_path = "/tmp/EasyBar/lua-runtime.sock"
watch_config = true
lock_dir = "/tmp/EasyBar"
widget_editor_stub_path = "~/.local/share/easybar/easybar_api.lua"
develop = false
```

## `widgets_dir`

The directory where EasyBar loads Lua widget files from.

```toml
[app]
widgets_dir = "~/.config/easybar/widgets"
```

Every `*.lua` file in this directory is loaded by the Lua runtime.

If you are creating your first custom widget, continue with [First Widget](../lua/guides/first-widget.md).

## `lua_path`

The Lua executable used for the Lua widget runtime.

```toml
[app]
lua_path = "/opt/homebrew/bin/lua"
```

Use an absolute path when EasyBar is launched as a GUI app or Homebrew service, because those sessions do not always inherit your shell startup files.

## `lua_socket_path`

The dedicated Unix socket used between the main app and the Lua widget runtime.

```toml
[app]
lua_socket_path = "/tmp/EasyBar/lua-runtime.sock"
```

This socket is separate from stderr logs. Runtime protocol messages use JSON over the Lua socket.

See [Runtime Control](../runtime/control.md) and [Lua Runtime Overview](../internals/lua-runtime/overview.md).

## `watch_config`

Controls whether EasyBar watches `config.toml` and reloads automatically when the file changes.

```toml
[app]
watch_config = true
```

When this is `false`, update the running app manually after config edits:

```bash
easybar --reload-config
```

## `lock_dir`

Directory used for EasyBar runtime lock files.

```toml
[app]
lock_dir = "/tmp/EasyBar"
```

The lock directory is part of the single-instance guard that prevents multiple EasyBar app processes from drawing duplicate bars.

## `widget_editor_stub_path`

Path where EasyBar keeps the combined LuaLS/editor stub in sync for widget authoring.

```toml
[app]
widget_editor_stub_path = "~/.local/share/easybar/easybar_api.lua"
```

Point your Lua language server workspace at this file to get autocomplete and diagnostics for the public EasyBar Lua API.

See [Editor Support](../lua/guides/editor-support.md).

## `develop`

The hidden developer menu section can be shown without holding `Shift` with:

```toml
[app]
develop = true
```

By default, the developer section is hidden unless you hold `Shift` and right-click the bar.

See [Developer Menu](developer-menu.md).

## `lua_commands`

Command execution limits for `easybar.exec(...)` and `easybar.exec_async(...)`.

```toml
[app.lua_commands]
timeout_seconds = 5
max_output_bytes = 65536
max_async_jobs = 8
```

- `timeout_seconds`: default hard timeout for one command before EasyBar terminates it. Widgets can override this per `easybar.exec(...)` or `easybar.exec_async(...)` call.
- `max_output_bytes`: default maximum combined stdout and stderr captured for one command. Widgets can override this per call.
- `max_async_jobs`: maximum concurrent `easybar.exec_async(...)` jobs before new jobs are rejected.

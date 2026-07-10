extension ConfigSchemaRegistry {
  static let coreLines: [Line] = [
    section(name: "app"),
    entry(
      key: "widgets_dir",
      value: "\"~/.config/easybar/widgets\"",
      description: "Directory that contains your custom Lua widget files.",
    ),
    entry(
      key: "lua_path",
      value: "\"lua\"",
      description: "Path to the Lua executable EasyBar uses for scripted widgets.",
    ),
    entry(
      key: "lua_socket_path",
      value: "\"$EASYBAR_RUNTIME_DIR/lua-runtime.sock\"",
      description:
        "Unix socket path used by EasyBar and the Lua widget runtime transport. $EASYBAR_RUNTIME_DIR expands to EasyBar's user-scoped temporary runtime directory.",
    ),
    entry(
      key: "watch_config",
      value: "true",
      description: "Reloads EasyBar automatically when config.toml changes.",
    ),
    entry(
      key: "lock_dir",
      value: "\"$EASYBAR_RUNTIME_DIR\"",
      description: "Directory that contains lock files used by EasyBar.",
    ),
    entry(
      key: "widget_editor_stub_path",
      value: "\"~/.local/share/easybar/easybar_api.lua\"",
      description: "LuaLS/editor stub path EasyBar keeps in sync for widget authoring.",
    ),
    entry(
      key: "develop",
      value: "false",
      description:
        "Shows the developer menu section without holding Shift when right-clicking the bar.",
    ),
    .blank,
    section(name: "app.env"),
    entry(
      key: "PATH",
      value: "\"/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin\"",
      description: "Environment overrides passed into the Lua runtime and widget shell commands.",
    ),
    .blank,
    section(name: "app.lua_commands"),
    entry(
      key: "timeout_seconds",
      value: "5",
      description: "Default hard timeout for easybar.exec and easybar.exec_async commands.",
    ),
    entry(
      key: "max_output_bytes",
      value: "65536",
      description: "Default combined stdout and stderr capture limit for one command.",
    ),
    entry(
      key: "max_async_jobs",
      value: "8",
      description: "Maximum concurrent easybar.exec_async jobs before new jobs are rejected.",
    ),
    .blank,
    section(name: "theme"),
    entry(
      key: "name",
      value: "\"default\"",
      description:
        "Name of the default theme. Must match a theme file name without the .toml extension.",
    ),
    entry(
      key: "themes_dir",
      value: "\"~/.config/easybar/themes\"",
      description: "Directory that contains your custom theme files.",
    ),
    .blank,
    section(name: "logging"),
    entry(
      key: "enabled",
      value: "false",
      description: "Mirrors stdout and stderr into per-process log files when true.",
    ),
    entry(
      key: "level",
      value: "\"info\"",
      description: "Minimum log level: trace | debug | info | warn | error.",
    ),
    entry(
      key: "directory",
      value: "\"~/.local/state/easybar\"",
      description:
        "Directory where EasyBar writes easybar.out, calendar-agent.out, and network-agent.out.",
    ),
    .blank,
    section(name: "agents.calendar"),
    entry(
      key: "enabled",
      value: "true",
      description:
        "Starts the calendar socket client in EasyBar and enables the calendar helper contract.",
    ),
    entry(
      key: "socket_path",
      value: "\"$EASYBAR_RUNTIME_DIR/calendar-agent.sock\"",
      description: "Unix socket path used by EasyBar and the calendar agent.",
    ),
    .blank,
    section(name: "agents.network"),
    entry(
      key: "enabled",
      value: "true",
      description:
        "Starts the network socket client in EasyBar and enables the Wi-Fi helper contract.",
    ),
    entry(
      key: "socket_path",
      value: "\"$EASYBAR_RUNTIME_DIR/network-agent.sock\"",
      description: "Unix socket path used by EasyBar and the network agent.",
    ),
    entry(
      key: "refresh_interval_seconds",
      value: "60",
      description: "Fallback polling interval for Wi-Fi state. Set to 0 to disable polling.",
    ),
    entry(
      key: "allow_unauthorized_non_sensitive_fields",
      value: "false",
      description:
        "When false, Wi-Fi field requests fail while location permission is denied. When true, only non-sensitive non-Wi-Fi fields may still be returned.",
    ),
    .blank,
    section(name: "bar"),
    entry(
      key: "height",
      value: "32",
      description: "Total height of the bar.",
    ),
    entry(
      key: "padding_x",
      value: "10",
      description: "Horizontal left and right padding inside the bar.",
    ),
    entry(
      key: "extend_behind_notch",
      value: "true",
      description: "Makes the bar span the full top edge, including the area behind the notch.",
    ),
    .blank,
    section(name: "bar.colors"),
    entry(
      key: "background",
      value: "\"theme.background\"",
      description: "Background color of the bar.",
    ),
    entry(
      key: "border",
      value: "\"theme.transparent\"",
      description: "Bottom border color of the bar. Use a visible color to opt in.",
    ),
    .blank,
  ]
}

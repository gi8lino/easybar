# Built-ins

EasyBar supports native built-in widgets in `config.toml`.

Built-ins are configured under `[builtins.*]`.

If you are deciding whether to use a built-in or write a Lua widget, start with [Built-ins Vs Lua](../getting-started/builtins-vs-lua.md).

Example:

```toml
[builtins.spaces]
enabled = true

[builtins.battery]
enabled = true

[builtins.wifi]
enabled = true

[builtins.calendar]
enabled = true
```

## Groups

Built-ins can be attached to native groups:

```toml
[builtins.groups.system]
position = "right"
order = 40

[builtins.groups.system.style]

[builtins.battery]
enabled = true
group = "system"

[builtins.wifi]
enabled = true
group = "system"
```

See [Native Groups](native-groups.md).

## Box model

Built-in widgets and native groups share common layout keys:

- `margin_x`
- `margin_y`
- `padding_x`
- `padding_y`
- `spacing`

See [Box Model](box-model.md).

## Spaces

For the native `spaces` widget:

- `[builtins.spaces]` controls the outer container placement and shared box model.
- `[builtins.spaces.layout]` controls the internal workspace-pill layout.

## When to switch to Lua

Stay with built-ins when the widget already exists and you mainly need native placement and styling.

Switch to Lua when you need:

- custom formatting or composed content
- custom mouse behavior
- popup content driven by your own data
- shell-command integration or app-specific logic

See [Lua Widgets](../lua/overview.md).

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

## Theme defaults

Built-ins receive visual defaults from the selected theme.

For example, a theme can provide default colors for:

- text
- surfaces
- borders
- status colors
- popup backgrounds
- active and inactive states

Explicit built-in config still wins.

Example:

```toml
[theme]
name = "mocha"

[builtins.time.style]
text_color = "#ffffff"
background_color = "#090909"
```

Here the time widget uses the explicit colors instead of the theme defaults.

See [Themes](themes.md).

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

## Calendar filters

Calendar filters are configured under `[builtins.calendar.filters]`.

Use `included_calendar_names` and `excluded_calendar_names` for the visible calendar titles you see in Calendar.app.

For advanced exact matching, you can also use:

- `included_calendar_ids`
- `excluded_calendar_ids`
- `included_calendar_source_ids`
- `excluded_calendar_source_ids`

Excludes always win over includes, and blank filter entries are ignored.

## When to switch to Lua

Stay with built-ins when the widget already exists and you mainly need native placement, grouping, theming, or styling.

Switch to Lua when you need:

- custom formatting or composed content
- custom mouse behavior
- popup content driven by your own data
- shell-command integration or app-specific logic

See [Lua Widgets](../lua/overview.md).

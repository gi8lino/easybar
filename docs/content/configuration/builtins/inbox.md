# Inbox

The native inbox collects structured snapshots published by Lua widgets into one bar item. It displays the total unread count and can group messages by source, date, category, severity, or not at all.

```toml
[builtins.inbox]
enabled = true
position = "right"
order = 5

[builtins.inbox.content]
group_by = "source"
show_unread_count = true
show_source_actions = true
popup_width = 360
popup_max_height = 440
use_inactive_style_when_read = true
show_when_empty = true
inactive_icon = "󰂜"
inactive_color = "theme.muted"
```

## Appearance

The active bell and unread counter can be colored independently:

```toml
[builtins.inbox.style]
icon_color = "theme.text_secondary"
unread_count_color = "theme.accent"
```

`text_color` is the icon fallback when `icon_color` is omitted. `[builtins.inbox.colors]` controls the popup background, border, title, body, muted labels, item background, actions, and severity indicators.

## Behavior

When there are no unread messages, `use_inactive_style_when_read` selects `inactive_icon` and `inactive_color`. Set `show_when_empty = false` to hide the anchor when no messages exist. Set `show_unread_count = false` to retain the stateful icon without its numeric badge.

The popup header exposes publisher-provided source submenus through its actions button. Set `show_source_actions = false` to hide these actions while retaining the inbox-wide controls.

See [Native Inbox for Lua](../../lua/guides/inbox.md) for publishing snapshots, limited Markdown, item actions, source actions, persistence, and dismissal behavior.

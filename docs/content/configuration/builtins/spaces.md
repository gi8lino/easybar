# Spaces

The native spaces widget renders AeroSpace workspaces and their visible application icons.

- `[builtins.spaces]` controls placement and the outer box model.
- `[builtins.spaces.layout]` controls the workspace-pill layout.
- `[builtins.spaces.text]` controls labels.
- `[builtins.spaces.icons]` controls application icons.

## Collapsed inactive spaces

The content settings interact as follows:

| `show_label` | `show_icons` | `collapse_inactive` | Result                                                                                   |
| ------------ | ------------ | ------------------- | ---------------------------------------------------------------------------------------- |
| `true`       | `true`       | `false`             | Shows every visible space with its label and app icons.                                  |
| `true`       | `true`       | `true`              | Shows the focused space with its label and icons; inactive spaces become compact labels. |
| `true`       | `false`      | `false`             | Shows every visible space as a label.                                                    |
| `true`       | `false`      | `true`              | Shows only the focused space label.                                                      |
| `false`      | `true`       | `false`             | Shows every visible space with app icons.                                                |
| `false`      | `true`       | `true`              | Shows only the focused space with app icons.                                             |
| `false`      | `false`      | either              | Renders no spaces widget and reports a configuration warning.                            |

This table assumes `show_only_focused_label = false`. When it is `true`, inactive labels are removed as well; an inactive space is omitted whenever it would have no visible content.

Disable the widget explicitly instead of configuring it with no visible content:

```toml
[builtins.spaces]
enabled = false
```

EasyBar requires AeroSpace 0.21.0 or newer. See [AeroSpace Integration](../../getting-started/aerospace.md) and [Recovery](../../runtime/recovery.md) for connection troubleshooting.

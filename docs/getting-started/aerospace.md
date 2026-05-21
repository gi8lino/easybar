# AeroSpace Integration

EasyBar relies on AeroSpace callbacks to refresh workspace, focus, and layout-mode state immediately.

Without these callbacks, EasyBar can still refresh manually, but AeroSpace-derived widgets may look stale until the next refresh.

## Workspace changes

Add this to your AeroSpace config:

```toml
exec-on-workspace-change = [
  'exec-and-forget /opt/homebrew/bin/easybar --workspace-changed'
]
```

## Focus changes

Add this too:

```toml
on-focus-changed = [
  'exec-and-forget /opt/homebrew/bin/easybar --focus-changed'
]
```

These callbacks keep built-in AeroSpace widgets in sync when the focused workspace or focused window changes.

## Layout mode changes

If you use the built-in AeroSpace mode widget, also trigger EasyBar whenever you change the current layout mode.

Example:

```toml
alt-e = [
  'layout tiles horizontal',
  'exec-and-forget /opt/homebrew/bin/easybar --space-mode-changed'
]

alt-v = [
  'layout tiles vertical',
  'exec-and-forget /opt/homebrew/bin/easybar --space-mode-changed'
]

alt-s = [
  'layout v_accordion',
  'exec-and-forget /opt/homebrew/bin/easybar --space-mode-changed'
]

alt-shift-space = [
  'layout floating tiling',
  'exec-and-forget /opt/homebrew/bin/easybar --space-mode-changed'
]
```

## Manual refresh

You can always trigger one refresh manually:

```bash
easybar --refresh
```

## Related pages

- [Runtime Control](../runtime/control.md)
- [Troubleshooting](../runtime/troubleshooting.md)

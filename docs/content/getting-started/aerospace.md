# AeroSpace Integration

EasyBar relies on AeroSpace callbacks to refresh workspace, focus, and layout-mode state immediately.

Without these callbacks, EasyBar can still refresh manually, but AeroSpace-derived widgets may look stale until the next refresh.

## Requirements

EasyBar v0.4.0 and newer require AeroSpace 0.21.0 or newer. The AeroSpace integration uses formatted JSON output from `aerospace list-workspaces` and `aerospace list-windows`; legacy text-output parsing was removed.

EasyBar v0.3.0 was the last release that supported text-based AeroSpace output. Use v0.3.0 only if you must keep an older AeroSpace version.

Check your AeroSpace versions with:

```bash
aerospace --version
```

Both the CLI client and the running AeroSpace.app server should be at least 0.21.0. If they differ after updating, restart AeroSpace.app.

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



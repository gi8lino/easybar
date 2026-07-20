# Developer Menu

EasyBar can expose a developer section in its shared native menu.

## Default behavior

By default:

- normal right-click shows the standard menu
- `Shift` + right-click also shows the hidden developer section
- the menu bar icon shows the section only when `[app].develop` is enabled

## Always show the developer section

Enable:

```toml
[app]
develop = true
```

## Developer actions

The developer section currently includes **Log Level**, which changes the active runtime log level.
**Open Log Folder** remains available in the standard file-actions group.

## Example

```toml
[app]
develop = true

[logging]
enabled = true
level = "info"
directory = "~/.local/state/easybar"
```

This is mainly intended for local debugging and troubleshooting.

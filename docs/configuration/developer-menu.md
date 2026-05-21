# Developer Menu

EasyBar can expose a developer section in the bar context menu.

## Default behavior

By default:

- normal right-click shows the standard menu
- `Shift` + right-click also shows the hidden developer section

## Always show the developer section

Enable:

```toml
[app]
develop = true
```

## Developer actions

The developer section currently includes:

- `Log Level`
  Switch the active runtime log level from the menu.
- `Open Log Folder`
  Open the configured log directory in Finder.

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

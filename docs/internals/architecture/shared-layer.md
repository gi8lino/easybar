# Shared Layer

The `EasyBarShared` target contains code used across multiple executables.

## Responsibilities

Typical responsibilities include:

- shared config models and config loading
- shared IPC request and response models
- shared socket path helpers
- shared environment-key definitions
- common logging utilities and log-level definitions
- value types used by both the app and helper processes

This target exists to keep the transport and configuration contracts consistent across the app, CLI, and agents.

If a type is part of a process boundary, it usually belongs here.

## Logging architecture

Logging is intentionally shared across the app, agents, and CLI.

The core pieces live in `EasyBarShared`:

- `ProcessLogger`
- the shared log level enum
- shared runtime logging config resolution
- startup snapshot logging helpers

The app and helper agents use config-driven logging:

```toml
[logging]
enabled = true
level = "info"
directory = "~/.local/state/easybar"
```

Supported levels:

- `trace`
- `debug`
- `info`
- `warn`
- `error`

That keeps the normal runtime logging model explicit and consistent across all long-lived processes.

The CLI remains slightly different on purpose:

- it can enable extra local debug output with `--debug`
- it may also honor `EASYBAR_DEBUG` for CLI-only behavior

That CLI-specific toggle is a developer convenience, not the main logging contract for the app or agents.

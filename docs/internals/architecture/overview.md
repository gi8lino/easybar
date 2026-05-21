# Architecture Overview

EasyBar is split into focused targets and process boundaries.

It has:

- a main macOS status bar app
- a command-line control client
- helper agents for calendar and network data
- a separate Lua runtime process
- shared models and transport types

## High-level runtime

```text
AeroSpace / macOS events / user input
                │
                ▼
            EasyBar app
                │
     ┌──────────┼──────────┐
     │          │          │
     ▼          ▼          ▼
 Lua runtime   calendar    network
  process       agent       agent
                │            │
                ▼            ▼
             EventKit   CoreWLAN / network APIs
```

There is also a separate CLI process:

```text
easybar CLI ─────► EasyBar control socket
```

## Design goals

The project is intentionally opinionated.

Key architectural goals are:

- keep the main UI process focused on rendering and widget coordination
- isolate permission-sensitive APIs in helper agents
- keep cross-process protocols explicit and typed
- prefer native Swift widgets for built-in functionality
- support Lua for custom widgets without making Lua the center of the whole system
- integrate cleanly with an AeroSpace-based workflow

## Main process responsibilities

The `EasyBar` target is the main app.

It is responsible for:

- starting the bar UI
- loading and validating config
- creating and positioning the bar window
- rendering native built-in widgets
- hosting the native interaction model
- running and supervising the Lua widget runtime
- consuming snapshots or field data from helper agents
- reacting to control-socket commands
- coordinating updates from macOS, AeroSpace, Lua, and agents

The main app should generally decide how state is presented, not gather every piece of raw system state itself.

Examples:

- the network agent returns Wi-Fi metrics, but EasyBar decides how to render signal bars
- the calendar agent returns normalized event snapshots, but EasyBar decides how they appear in the bar and popups

## Related pages

- [Targets](targets.md)
- [Process Model](process-model.md)
- [Shared Layer](shared-layer.md)
- [CLI](cli.md)
- [Control Socket](control-socket.md)
- [Event Flow](event-flow.md)
- [Boundaries](boundaries.md)

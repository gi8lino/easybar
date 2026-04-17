# EasyBar Architecture

This document explains how EasyBar is structured internally and how the main app, helper agents, CLI, and Lua runtime fit together.

It is meant for contributors who want to understand the project layout and the boundaries between the main components.

## High-level overview

EasyBar is split into a few focused targets:

- `EasyBarShared`
  shared models, config loading, socket paths, IPC types, logging utilities, environment keys, and common runtime helpers
- `EasyBar`
  the main macOS status bar application
- `EasyBarCtl`
  the `easybar` command-line client
- `EasyBarCalendarAgent`
  helper app that owns calendar access and EventKit operations
- `EasyBarNetworkAgent`
  helper app that owns Wi-Fi and network observation
- `EasyBarNetworkAgentCore`
  shared reusable network-agent logic used by `EasyBarNetworkAgent` and also by the standalone `wifi-snitch` project

At runtime, the system looks like this:

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

## Shared layer

The `EasyBarShared` target contains code used across multiple executables.

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

Supported levels are:

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

## CLI boundary

The `EasyBarCtl` target builds the `easybar` executable.

It is a thin client for the main app control socket.

Its job is to:

- translate CLI flags into typed control commands
- connect to the EasyBar Unix socket
- send JSON requests
- decode typed JSON responses
- report success or failure to the shell

This keeps automation simple and avoids forcing users to speak the socket protocol manually.

Typical examples:

- `easybar --refresh`
- `easybar --restart-lua-runtime`
- `easybar --reload-config`
- `easybar --space-mode-changed`

The CLI should stay small. It is a transport client, not a second source of application logic.

## Control socket architecture

EasyBar exposes a local Unix control socket for commands sent by the CLI or other local clients.

The control socket is used for commands such as:

- `workspace_changed`
- `focus_changed`
- `space_mode_changed`
- `manual_refresh`
- `restart_lua_runtime`
- `reload_config`
- `metrics`

Requests and responses are typed JSON.

That boundary exists so that:

- AeroSpace callbacks can trigger EasyBar updates cleanly
- shell scripts can refresh or reload the app safely
- external integrations do not need direct access to internal app objects

The control socket is a command interface, not a general event stream.

## Why helper agents exist

EasyBar uses out-of-process agents for permission-sensitive and system-observation-heavy features.

The reasons are practical:

- keep sensitive APIs out of the main UI process
- isolate permission handling
- reduce coupling between rendering and data collection
- improve reliability when permission state changes
- make the boundary explicit with typed socket protocols

This is especially important for:

- EventKit access
- Wi-Fi and network information that depends on location permission

The agents collect and normalize data.
EasyBar consumes that data and renders UI from it.

## Calendar agent

The `EasyBarCalendarAgent` target owns `EventKit`.

It is responsible for:

- requesting calendar permission
- observing calendar changes
- fetching events in requested time windows
- building normalized event snapshots
- preparing sectioned popup data
- creating, updating, and deleting events
- pushing updates to subscribed clients

This keeps all calendar permission and mutation logic out of the main app process.

The calendar agent communicates with EasyBar over a local Unix socket with newline-delimited JSON messages.

Important behavior:

- `fetch` returns a snapshot and closes
- `subscribe` keeps the socket open and pushes later updates
- event mutations are performed in the agent, not in the main app

This means EasyBar never needs to own `EventKit` directly.

## Network agent

The `EasyBarNetworkAgent` target owns Wi-Fi and network observation that depends on location permission.

It is responsible for:

- requesting location authorization for Wi-Fi details
- observing Wi-Fi changes
- observing primary interface changes
- collecting network field values
- smoothing RSSI samples
- serving only the requested fields to clients
- pushing updates to subscribed clients

The network agent returns typed field maps rather than UI-specific models.

Examples of fields include:

- Wi-Fi identity and radio metrics
- primary interface state
- tunnel detection
- IP and DNS details
- reachability state
- permission state

This keeps policy and rendering separate:

- the agent gathers and exposes raw network state
- EasyBar decides how to display it

## Network agent core

`EasyBarNetworkAgentCore` contains the reusable implementation behind the network agent.

It exists because the same core network-observation and field-serving logic is used in two places:

- `EasyBarNetworkAgent`, the EasyBar helper app
- `wifi-snitch`, a standalone project built around the same network-agent behavior

This separation keeps the executable target smaller and makes the network agent easier to evolve.

## Lua runtime boundary

Lua widgets do not run in-process inside the main app.

EasyBar starts a separate Lua process and communicates with it over standard input and output using JSON lines.

That gives the project a clean boundary:

- Swift owns windowing, rendering, and native services
- Lua owns custom widget scripts and script-driven widget state
- JSON is the transport between the two

Benefits of the separate process:

- crash isolation
- easier reloads
- full runtime reset on restart
- a simpler mental model for widget execution
- clearer logging and transport behavior

The Lua runtime flow is:

1. EasyBar starts the Lua process
2. Lua loads widget files from the widget directory
3. Lua declares which events it needs
4. Swift starts only the necessary event sources
5. Swift sends normalized events to Lua
6. Lua updates widget state and emits rendered trees
7. Swift decodes those trees and applies them to the widget store

This design intentionally avoids embedding arbitrary Lua execution into the UI process.

For more detail, see [LUA_RUNTIME.md](./LUA_RUNTIME.md) and [LUA_WIDGETS.md](./LUA_WIDGETS.md).

## Native widgets vs Lua widgets

EasyBar supports two extension styles:

- native built-in widgets written in Swift
- custom widgets written in Lua

The intended architecture is Swift-first.

That means:

- common platform-integrated widgets should live natively when possible
- Lua is the extension layer for custom behavior, experiments, and user-specific integrations

Why this split exists:

- native Swift code is better for deep macOS integration
- native widgets fit the main app architecture more naturally
- Lua gives flexibility without forcing the whole bar to become a scripting engine

So Lua is an important part of the project, but not the architectural center of it.

## Event flow

EasyBar reacts to several kinds of events:

- macOS state changes
- AeroSpace-related changes
- agent socket updates
- Lua runtime subscriptions
- direct control-socket commands
- user interaction such as clicks, hover, scroll, and sliders

A simplified event flow looks like this:

```text
system event / app trigger / AeroSpace callback
                    │
                    ▼
               EasyBar event layer
                    │
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
   native widget   Lua runtime   agent fetch/subscription
     updates         updates          handling
```

The important design choice is that EasyBar acts as the coordinator.

It does not let every subsystem talk to every other subsystem directly.

## Configuration architecture

EasyBar, the agents, and related helper processes all read the same runtime config file.

Default path:

```text
~/.config/easybar/config.toml
```

Optional override:

```bash
EASYBAR_CONFIG_PATH=/path/to/config.toml
```

The config controls:

- built-in widgets
- native groups
- agent enablement
- socket paths
- logging
- widget directories
- runtime behavior

Using one shared config keeps the system easier to reason about.

The agents still remain independent processes, but they follow the same configuration contract as the main app.

## Process model

At a high level, the runtime process model is:

- one `EasyBar` app process
- zero or one `EasyBarCalendarAgent` process
- zero or one `EasyBarNetworkAgent` process
- one `easybar` CLI process per command invocation
- one Lua runtime child process owned by the main app when Lua widgets are enabled

The project also uses a single-instance guard for the main app to avoid duplicate bars.

That matters because duplicate processes are one of the most common causes of confusing behavior in status bar apps.

## Directory and target intent

A useful way to think about the targets is:

- `Sources/EasyBarShared`
  process-boundary types and shared utilities
- `Sources/EasyBar`
  app lifecycle, UI, event coordination, native widgets, Lua supervision
- `Sources/EasyBarCtl`
  command-line control client
- `Sources/EasyBarCalendarAgent`
  calendar permission and snapshot service
- `Sources/EasyBarNetworkAgent`
  network-agent executable entrypoint and app lifecycle
- `Sources/EasyBarNetworkAgentCore`
  reusable network-agent internals

That structure reflects runtime responsibilities, not only package-manager convenience.

## Architectural boundaries to preserve

When adding features, try to preserve these boundaries:

### Keep UI decisions in EasyBar

The main app should decide how data is shown.

Do not move presentation-specific mapping into agents unless it is impossible to avoid.

Examples:

- good: network agent returns RSSI, EasyBar maps it to bars
- good: calendar agent returns normalized event data, EasyBar chooses the UI style
- less ideal: agent returns pre-rendered user-facing labels that only the UI cares about

### Keep permission ownership in agents

If a feature depends on permission-sensitive APIs, prefer to keep that API ownership in the relevant agent.

That keeps the boundary clean and reduces surprises in the main app process.

### Keep cross-process protocols typed

If two processes exchange data, define the request and response models clearly.

Avoid ad-hoc string protocols when typed JSON models already exist.

### Keep the CLI thin

The CLI should remain a transport layer for user commands.
It should not duplicate app behavior or reimplement app state.

### Keep Lua transport simple

The Lua boundary should stay easy to inspect and debug:

- JSON in
- JSON out
- stderr logs

Avoid making the protocol unnecessarily magical.

## How to choose where new code belongs

A practical guideline:

- put code in `EasyBarShared` if it is used across executables or defines a boundary contract
- put code in `EasyBar` if it is UI-facing or app-coordination logic
- put code in an agent target if it owns permission-sensitive collection or mutation logic
- put code in `EasyBarNetworkAgentCore` if it is reusable network-agent internals, not app entrypoint code
- put code in Lua only when the feature is meant to be scriptable or user-customizable

Questions that help:

- does this code need to talk directly to a sensitive system API?
- is this logic about collecting data or presenting it?
- is this a stable contract between processes?
- is this meant for built-in native functionality or user scripting?

## Related documents

- [CONFIG.md](./CONFIG.md)
  runtime config structure and built-in group behavior
- [AGENTS.md](./AGENTS.md)
  calendar and network agent responsibilities and wire protocols
- [LUA_RUNTIME.md](./LUA_RUNTIME.md)
  internal Lua runtime architecture
- [LUA_WIDGETS.md](./LUA_WIDGETS.md)
  public Lua widget API and authoring model

## Summary

EasyBar is built around a few strong boundaries:

- the main app renders and coordinates
- helper agents own permission-sensitive system APIs
- the CLI talks to the app through a typed control socket
- Lua runs out of process as a scriptable widget runtime
- shared contracts live in `EasyBarShared`

That structure keeps the project easier to reason about as it grows, while still allowing native widgets, Lua widgets, helper agents, and AeroSpace integration to work together cleanly.

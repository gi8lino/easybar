# Architectural Boundaries

When adding features, preserve the project boundaries.

## Keep UI decisions in EasyBar

The main app should decide how data is shown.

Do not move presentation-specific mapping into agents unless it is impossible to avoid.

Examples:

- good: network agent returns RSSI, EasyBar maps it to bars
- good: calendar agent returns normalized event data, EasyBar chooses the UI style
- less ideal: agent returns pre-rendered user-facing labels that only the UI cares about

## Keep permission ownership in agents

If a feature depends on permission-sensitive APIs, prefer to keep that API ownership in the relevant agent.

That keeps the boundary clean and reduces surprises in the main app process.

## Keep cross-process protocols typed

If two processes exchange data, define the request and response models clearly.

Avoid ad-hoc string protocols when typed JSON models already exist.

## Keep the CLI thin

The CLI should remain a transport layer for user commands.

It should not duplicate app behavior or reimplement app state.

## Keep Lua transport simple

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
- put code in `EasyBarCalendarCore` if it is reusable calendar-agent internals, not app entrypoint code
- put code in `EasyBarCalendarPresentation` if it is reusable calendar request or presentation logic that should not depend on EasyBar widget infrastructure
- put code in `EasyBarCalendarUI` if it is reusable calendar SwiftUI or calendar-only view state that should not depend on EasyBar panels, widget trees, or app shell wiring
- put code in `EasyBarNetworkAgentCore` if it is reusable network-agent internals, not app entrypoint code
- put code in Lua only when the feature is meant to be scriptable or user-customizable

Useful questions:

- does this code need to talk directly to a sensitive system API?
- is this logic about collecting data or presenting it?
- is this a stable contract between processes?
- is this meant for built-in native functionality or user scripting?

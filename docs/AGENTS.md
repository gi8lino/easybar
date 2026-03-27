# EasyBar agents

EasyBar uses two helper agents for permission-sensitive data sources.

## Calendar agent

`easybar-calendar-agent` owns `EventKit`.

It:

- requests Calendar permission
- watches calendar store changes
- builds cached calendar snapshots
- pushes those snapshots to EasyBar over a local Unix socket

This keeps Calendar permission and `EventKit` state in one dedicated process instead of the UI process.

## Network agent

`easybar-network-agent` owns Wi-Fi and network state that depends on location permission.

It:

- requests location access required for SSID and signal strength
- watches Wi-Fi and network changes
- builds cached network snapshots
- pushes those snapshots to EasyBar over a local Unix socket

This keeps Wi-Fi permission handling and network monitoring in one dedicated process instead of the UI process.

## Why EasyBar uses agents

The agents exist to make permission-sensitive widgets more reliable.

EasyBar itself stays focused on:

- rendering the bar
- managing widgets
- consuming cached snapshots

The agents focus on:

- permission ownership
- data collection
- change observation

## Services

In the Homebrew setup, both agents run as their own `brew services` services:

```bash
brew services start gi8lino/tap/easybar-calendar-agent
brew services start gi8lino/tap/easybar-network-agent
```

EasyBar then connects to them over local Unix sockets.

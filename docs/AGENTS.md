# EasyBar Agents

EasyBar uses two helper processes:

- `easybar-calendar-agent`
- `easybar-network-agent`

Both run out of process, listen on a local Unix socket, and exchange newline-delimited JSON messages with EasyBar.

## Why agents exist

The agents keep permission-sensitive system APIs out of the main UI process.

EasyBar stays focused on:

- rendering the bar
- managing widgets
- consuming snapshots from helper processes

The agents stay focused on:

- permission ownership
- system observation
- raw snapshot collection
- socket delivery

The important boundary is:

- agents collect and return data
- EasyBar decides how that data is rendered

For example, the network agent returns RSSI, while EasyBar maps RSSI into Wi-Fi bars.

## Runtime config

Both agents load the shared runtime config from:

- `EASYBAR_CONFIG_PATH`, when set
- otherwise `~/.config/easybar/config.toml`

Relevant config:

```toml
[logging]
enabled = false
debug = false
directory = "~/.local/state/easybar"

[agents.calendar]
socket_path = "/tmp/EasyBar/calendar-agent.sock"

[agents.network]
socket_path = "/tmp/EasyBar/network-agent.sock"
refresh_interval_seconds = 60
```

The agents also respect environment overrides for:

- config path
- debug logging
- socket paths
- network refresh interval

## Socket paths

Default sockets:

- calendar agent: `/tmp/EasyBar/calendar-agent.sock`
- network agent: `/tmp/EasyBar/network-agent.sock`

EasyBar connects to those sockets directly.

## Common protocol shape

Both agents support the same command flow:

- `ping`
- `fetch`
- `subscribe`

Both respond with a `kind` field:

- `pong`
- `subscribed`
- `snapshot`
- `error`

Typical behavior:

- `ping`
  returns one `pong`, then closes
- `fetch`
  returns one `snapshot`, then closes
- `subscribe`
  returns one `subscribed`
  returns one immediate `snapshot`
  keeps the socket open for later `snapshot` pushes

---

# Calendar Agent

`easybar-calendar-agent` owns `EventKit`.

It is responsible for:

- requesting calendar access
- observing `EKEventStore` changes
- building sectioned calendar snapshots
- pushing those snapshots to EasyBar

## Calendar requests

Request shape:

```json
{
  "command": "ping | fetch | subscribe",
  "query": {
    "days": 3,
    "showBirthdays": true,
    "emptyText": "No upcoming events",
    "birthdaysTitle": "Birthdays",
    "birthdaysDateFormat": "dd.MM.yyyy",
    "birthdaysShowAge": false
  }
}
```

Notes:

- `query` is optional for `ping`
- `query` is required for `fetch` and `subscribe`

## Calendar responses

Response shape:

```json
{
  "kind": "pong | subscribed | snapshot | error",
  "snapshot": { ... },
  "message": "optional error string"
}
```

## Calendar snapshot

Snapshot shape:

```json
{
  "accessGranted": true,
  "permissionState": "authorized",
  "generatedAt": "2026-03-29T12:34:56Z",
  "sections": [
    {
      "id": "birthdays",
      "title": "Birthdays",
      "kind": "birthdays",
      "items": [
        {
          "id": "birthday-...",
          "time": "31.03.2026",
          "title": "Jane Doe",
          "calendarName": "Birthdays",
          "calendarColorHex": "#FF9500"
        }
      ]
    }
  ]
}
```

Important fields:

- `accessGranted`
  whether calendar access is currently available
- `permissionState`
  current EventKit permission state
- `generatedAt`
  snapshot timestamp
- `sections`
  already grouped logical popup sections

Section kinds:

- `birthdays`
- `today`
- `tomorrow`
- `future`

Item fields:

- `id`
- `time`
- `title`
- `calendarName`
- `calendarColorHex`

Behavior notes:

- if access is unavailable, the agent returns `accessGranted = false` and `sections = []`
- birthdays come only from birthday calendars
- normal events come only from non-birthday calendars
- empty day sections are kept so popup layout stays stable
- title normalization happens in the agent

---

# Network Agent

`easybar-network-agent` owns Wi-Fi and primary-network observation that depends on location permission.

It is responsible for:

- requesting location access needed for Wi-Fi details
- observing Wi-Fi SSID changes
- observing primary interface changes
- smoothing RSSI samples
- pushing network snapshots to EasyBar

It is not responsible for UI rendering decisions like Wi-Fi bar mapping.

## Network requests

Request shape:

```json
{
  "command": "ping | fetch | subscribe"
}
```

## Network responses

Response shape:

```json
{
  "kind": "pong | subscribed | snapshot | error",
  "snapshot": { ... },
  "message": "optional error string"
}
```

## Network snapshot

Snapshot shape:

```json
{
  "accessGranted": true,
  "permissionState": "authorized_when_in_use",
  "generatedAt": "2026-03-29T12:34:56Z",
  "ssid": "Office WiFi",
  "interfaceName": "en0",
  "primaryInterfaceIsTunnel": false,
  "rssi": -64
}
```

Important fields:

- `accessGranted`
  whether Wi-Fi details are available
- `permissionState`
  current Core Location permission state
- `generatedAt`
  snapshot timestamp
- `ssid`
  current Wi-Fi SSID when available
- `interfaceName`
  current Wi-Fi interface name, for example `en0`
- `primaryInterfaceIsTunnel`
  whether the current primary interface looks like a tunnel
- `rssi`
  optional smoothed RSSI value

Tunnel detection currently matches interface names starting with:

- `utun`
- `ppp`
- `ipsec`
- `tap`
- `tun`

Behavior notes:

- if access is unavailable, the agent still returns a snapshot
- in that state, `ssid`, `interfaceName`, and `rssi` are `null`
- the agent smooths RSSI before publishing it
- EasyBar maps RSSI into visible Wi-Fi bars in the native widget layer
- the agent also supports a periodic fallback refresh interval

---

# Services

In the Homebrew setup, both agents can run as separate services:

```bash
brew services start gi8lino/tap/easybar-calendar-agent
brew services start gi8lino/tap/easybar-network-agent
```

EasyBar then connects to them over the local Unix sockets described above.

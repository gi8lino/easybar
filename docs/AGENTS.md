# EasyBar Agents

EasyBar uses two helper processes:

- `easybar-calendar-agent`
- `easybar-network-agent`

Both run out of process, listen on a local Unix socket, and exchange newline-delimited JSON messages with clients.

The main client is EasyBar itself, but the network agent protocol is also reused by standalone clients such as `wifi-snitch`.

## Why agents exist

The agents keep permission-sensitive system APIs out of the main UI process.

EasyBar stays focused on:

- rendering the bar
- managing widgets
- consuming agent data and building UI state

The agents stay focused on:

- permission ownership
- system observation
- raw data collection
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
enabled = true
socket_path = "/tmp/EasyBar/calendar-agent.sock"

[agents.network]
enabled = true
socket_path = "/tmp/EasyBar/network-agent.sock"
refresh_interval_seconds = 60
allow_unauthorized_non_sensitive_fields = false
```

The agents also respect environment overrides for:

- config path
- debug logging
- socket paths
- network refresh interval

If an agent is disabled in config, the helper app exits immediately without opening its socket.

## Socket paths

Default sockets:

- calendar agent: `/tmp/EasyBar/calendar-agent.sock`
- network agent: `/tmp/EasyBar/network-agent.sock`

EasyBar connects to those sockets directly.

Other local clients can also connect when they speak the same protocol.

## Common protocol shape

Both agents support the same basic command flow:

- `ping`
- `fetch`
- `subscribe`

Both respond with a `kind` field such as:

- `pong`
- `subscribed`
- `error`

Typical behavior:

- `ping`
  returns one `pong`, then closes
- `fetch`
  returns one data payload, then closes
- `subscribe`
  returns one `subscribed`
  returns one immediate data payload
  keeps the socket open for later pushes

The payload shape depends on the agent:

- calendar agent
  returns one typed `snapshot`
- network agent
  returns one typed `fields` map with only the requested keys

The calendar agent also supports event mutations and additional response kinds:

- `create_event`
- `update_event`
- `delete_event`

Mutation responses use:

- `created`
- `updated`
- `deleted`
- `error`

## How EasyBar uses agent data

EasyBar keeps long-lived subscriptions open to the agents for normal runtime updates.

A manual `easybar --refresh` does not reload the app config and does not restart the agents.
Instead, it tells the already running EasyBar process to refresh using the currently loaded config.

In practice, that means EasyBar can trigger fresh agent reads and republish updated UI state without rebuilding the whole app.

`easybar --reload-config` is different:

- it reloads `config.toml` from disk
- it rebuilds EasyBar runtime state from the new config
- it recreates agent-backed runtime pieces using the updated settings

So the distinction is:

- `refresh`
  refresh current runtime state and pull fresh data
- `reload-config`
  rebuild runtime state from a newly loaded config file

---

# Calendar Agent

`easybar-calendar-agent` owns `EventKit`.

It is responsible for:

- requesting calendar access
- observing `EKEventStore` changes
- building normalized event snapshots
- building sectioned popup data
- separating travel time from regular alerts
- tagging holiday-calendar events for UI decisions
- creating, updating, and deleting events
- pushing snapshots to subscribers

Calendar data exposed by the agent includes:

- normalized event windows for the month popup and upcoming popup
- birthday calendar events
- per-event travel time
- per-event alert presence
- per-event holiday-calendar tagging
- writable calendar lists for the composer
- mutation support for create, update, and delete

## Calendar requests

Request shape:

```json
{
  "command": "ping | fetch | subscribe | create_event | update_event | delete_event",
  "query": {
    "startDate": "2026-03-29T00:00:00Z",
    "endDate": "2026-04-01T00:00:00Z",
    "sectionStartDate": "2026-03-29T12:34:56Z",
    "sectionDayCount": 3,
    "showBirthdays": true,
    "emptyText": "No upcoming events",
    "birthdaysTitle": "Birthdays",
    "birthdaysDateFormat": "dd.MM.yyyy",
    "birthdaysShowAge": false,
    "includedCalendarNames": [],
    "excludedCalendarNames": []
  },
  "createEvent": null,
  "updateEvent": null,
  "deleteEvent": null
}
```

Notes:

- `query` is optional for `ping`
- `query` is required for `fetch` and `subscribe`
- `startDate` is the inclusive fetch start
- `endDate` is the exclusive fetch end
- `sectionStartDate` and `sectionDayCount` are optional and only used to build popup sections
- `includedCalendarNames` acts as an allowlist when non-empty
- `excludedCalendarNames` acts as a denylist
- birthday calendars are handled separately from normal calendars

### Create event request

```json
{
  "command": "create_event",
  "createEvent": {
    "title": "Team Sync",
    "startDate": "2026-03-29T09:00:00Z",
    "endDate": "2026-03-29T10:00:00Z",
    "isAllDay": false,
    "calendarName": "Work",
    "location": "Meeting Room",
    "alertOffsetsSeconds": [3600, 600],
    "travelTimeSeconds": 900
  }
}
```

### Update event request

```json
{
  "command": "update_event",
  "updateEvent": {
    "eventIdentifier": "ABC123",
    "title": "Team Sync",
    "startDate": "2026-03-29T09:30:00Z",
    "endDate": "2026-03-29T10:30:00Z",
    "isAllDay": false,
    "calendarName": "Work",
    "location": "Meeting Room",
    "alertOffsetsSeconds": [3600, 600],
    "travelTimeSeconds": 900
  }
}
```

### Delete event request

```json
{
  "command": "delete_event",
  "deleteEvent": {
    "eventIdentifier": "ABC123"
  }
}
```

## Calendar responses

Response shape:

```json
{
  "kind": "pong | subscribed | snapshot | created | updated | deleted | error",
  "snapshot": { ... },
  "message": "optional error string"
}
```

Notes:

- `snapshot` is present for `snapshot`
- `message` is typically only present for `error`
- mutation commands return `created`, `updated`, or `deleted` on success

## Calendar snapshot

Snapshot shape:

```json
{
  "accessGranted": true,
  "permissionState": "authorized",
  "generatedAt": "2026-03-29T12:34:56Z",
  "events": [
    {
      "id": "ABC123-1774774800",
      "title": "Team Sync",
      "startDate": "2026-03-29T09:00:00Z",
      "endDate": "2026-03-29T10:00:00Z",
      "isAllDay": false,
      "calendarName": "Work",
      "calendarColorHex": "#0A84FF",
      "location": "Meeting Room",
      "isHoliday": false,
      "hasAlert": true,
      "travelTimeSeconds": 900
    }
  ],
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
          "calendarColorHex": "#FF9500",
          "location": null,
          "travelTimeSeconds": null
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
- `events`
  normalized events in the requested fetch window
- `sections`
  optional pre-grouped popup sections

Section kinds:

- `birthdays`
- `today`
- `tomorrow`
- `future`

### Calendar event fields

- `id`
- `title`
- `startDate`
- `endDate`
- `isAllDay`
- `calendarName`
- `calendarColorHex`
- `location`
- `isHoliday`
- `hasAlert`
- `travelTimeSeconds`

### Calendar section item fields

- `id`
- `time`
- `title`
- `calendarName`
- `calendarColorHex`
- `location`
- `travelTimeSeconds`

Behavior notes:

- if access is unavailable, the agent returns `accessGranted = false`, `events = []`, and `sections = []`
- birthdays come only from birthday calendars
- normal events come only from non-birthday calendars
- travel time only comes from real EventKit travel-time data
- regular alerts are tracked separately from travel time
- holiday calendars are tagged in the agent so EasyBar can make display choices without talking to EventKit
- empty day sections are kept so popup layout stays stable
- title normalization happens in the agent
- when calendar permission is `not_determined`, the agent retries access requests with an incremental backoff until the state resolves
- sections are only built when `sectionStartDate` and `sectionDayCount` are provided
- `fetch` and `subscribe` can be used both for the upcoming popup and the month popup
- create, update, and delete are handled by the agent so EventKit mutation stays out of the main app process

---

# Network Agent

`easybar-network-agent` owns Wi-Fi and primary-network observation that depends on location permission.

It is responsible for:

- requesting location access needed for Wi-Fi details
- observing Wi-Fi SSID changes
- observing primary interface changes
- smoothing RSSI samples
- serving field-query responses to EasyBar and other clients

Network data exposed by the agent includes:

- Wi-Fi identity and radio metrics
- primary interface and tunnel state
- IP, gateway, and DNS details
- reachability and captive-portal state
- location authorization state
- ad-hoc fetch and long-lived subscribe responses over the same field-query protocol

It is not responsible for UI rendering decisions like Wi-Fi bar mapping.

The reusable implementation behind this protocol lives in `EasyBarNetworkAgentCore`.
That core is used by:

- `EasyBarNetworkAgent`
- the standalone `wifi-snitch` project

## Network requests

Request shape:

```json
{
  "command": "ping | fetch | subscribe",
  "fields": [
    "auth.location_authorized",
    "auth.location_permission_state",
    "network.generated_at",
    "wifi.ssid",
    "wifi.interface",
    "network.primary_interface_is_tunnel",
    "wifi.rssi"
  ]
}
```

Notes:

- `fields` is optional for `ping`
- `fields` is required for `fetch` and `subscribe`
- the agent returns only the requested keys
- when location permission is denied, requests for Wi-Fi fields fail by default
- `allow_unauthorized_non_sensitive_fields = true` allows non-Wi-Fi fields to keep working
- field values are typed on the wire, not stringified
- when location permission is `not_determined`, the agent retries authorization checks with an incremental backoff until the state resolves

## Network responses

Response shape:

```json
{
  "kind": "pong | subscribed | fields | error",
  "fields": {
    "auth.location_authorized": true,
    "auth.location_permission_state": "authorized",
    "network.generated_at": "2026-03-29T12:34:56Z",
    "wifi.ssid": "Office WiFi",
    "wifi.interface": "en0",
    "network.primary_interface_is_tunnel": false,
    "wifi.rssi": -64,
    "network.dns_servers": ["1.1.1.1", "8.8.8.8"]
  },
  "message": "optional error string"
}
```

Field value types:

- strings
  names, identifiers, timestamps, labels, addresses
- booleans
  auth and reachability flags
- integers
  RSSI, noise, SNR, link quality, channel, tx rate
- doubles
  numeric values that are not represented as integers
- string arrays
  DNS servers and active tunnel interfaces

## Network fields

Supported field keys:

- `wifi.ssid`
- `wifi.bssid`
- `wifi.interface`
- `wifi.hardware_address`
- `wifi.power`
- `wifi.service_active`
- `wifi.rssi`
- `wifi.noise`
- `wifi.snr`
- `wifi.link_quality`
- `wifi.tx_rate`
- `wifi.channel`
- `wifi.channel_band`
- `wifi.channel_width`
- `wifi.security`
- `wifi.phy_mode`
- `wifi.interface_mode`
- `wifi.country_code`
- `wifi.roaming`
- `wifi.ssid_changed_at`
- `wifi.interface_changed_at`
- `network.primary_interface`
- `network.active_tunnel_interface`
- `network.active_tunnel_interfaces`
- `network.primary_interface_is_tunnel`
- `network.ipv4_address`
- `network.ipv6_address`
- `network.default_gateway`
- `network.dns_servers`
- `network.internet_reachable`
- `network.captive_portal`
- `auth.location_authorized`
- `auth.location_permission_state`
- `network.generated_at`

Behavior notes:

- the agent smooths RSSI before returning `wifi.rssi`
- the agent does not map RSSI into Wi-Fi bars
- EasyBar reconstructs its local typed Wi-Fi state from the returned typed field map
- callers can use `fetch` for ad-hoc reads or `subscribe` for pushed updates
- the shared field registry in code is the source of truth for field help text

Tunnel detection currently matches interface names starting with:

- `utun`
- `ppp`
- `ipsec`
- `tap`
- `tun`

Additional behavior notes:

- if location access is unavailable, Wi-Fi-specific requests fail by default with `permission_denied:<state>`
- network fields can still be returned when they do not depend on Wi-Fi permission
- EasyBar maps RSSI into visible Wi-Fi bars in the native widget layer
- the agent also supports a periodic fallback refresh interval
- the permission bootstrap retry sequence is `1, 2, 3, 5, 8, 13, 21, 34, 55, 60` seconds and then repeats every `60s`

---

# Services

In the Homebrew setup, both agents can run as separate services:

```bash
brew services start gi8lino/tap/easybar-calendar-agent
brew services start gi8lino/tap/easybar-network-agent
```

EasyBar then connects to them over the local Unix sockets described above.

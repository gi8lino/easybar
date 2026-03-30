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

## Common protocol shape

Both agents support the same command flow:

- `ping`
- `fetch`
- `subscribe`

Both respond with a `kind` field:

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
  returns one `fields` map with only the requested keys

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
- serving field-query responses to EasyBar and other clients

It is not responsible for UI rendering decisions like Wi-Fi bar mapping.

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

## Network responses

Response shape:

```json
{
  "kind": "pong | subscribed | fields | error",
  "fields": {
    "auth.location_authorized": "true",
    "auth.location_permission_state": "authorized",
    "network.generated_at": "2026-03-29T12:34:56Z",
    "wifi.ssid": "Office WiFi",
    "wifi.interface": "en0",
    "network.primary_interface_is_tunnel": "false",
    "wifi.rssi": "-64"
  },
  "message": "optional error string"
}
```

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
- EasyBar reconstructs its local typed Wi-Fi state from the returned field map
- callers can use `fetch` for ad-hoc reads or `subscribe` for pushed updates
- the shared field registry in code is the source of truth for field help text

Tunnel detection currently matches interface names starting with:

- `utun`
- `ppp`
- `ipsec`
- `tap`
- `tun`

Behavior notes:

- if location access is unavailable, Wi-Fi-specific fields may be absent
- network fields can still be returned when they do not depend on Wi-Fi permission
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

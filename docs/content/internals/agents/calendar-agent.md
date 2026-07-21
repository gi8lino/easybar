# Calendar Agent

`easybar-calendar-agent` owns EventKit.

It is responsible for:

- requesting calendar access
- observing changes
- building normalized snapshots
- grouping popup sections
- handling event mutations
- pushing updates to subscribers

## Requests

```json
{
  "command": "ping | version | fetch | subscribe | create_event | update_event | delete_event",
  "query": {
    "startDate": "2026-03-29T00:00:00Z",
    "endDate": "2026-04-01T00:00:00Z"
  }
}
```

Notes:

- `query` is required for `fetch` and `subscribe`
- date range is inclusive/exclusive and must be forward, finite, and bounded
- section counts, filter arrays, text, identifiers, alerts, and mutation durations are bounded before EventKit work begins
- filters are applied server-side to regular and birthday calendars

## Responses

```json
{
  "kind": "snapshot",
  "snapshot": { ... }
}
```

Other kinds:

- `pong`
- `version`
- `subscribed`
- `created`
- `updated`
- `deleted`
- `error`

## Snapshot

```json
{
  "accessGranted": true,
  "permissionState": "authorized",
  "generatedAt": "2026-03-29T12:34:56Z",
  "events": [],
  "sections": []
}
```

## Event fields

- `id`
- `title`
- `startDate`
- `endDate`
- `isAllDay`
- `calendarName`
- `calendarColorHex`
- `location`
- `url` (direct EventKit URL, or the first URL EasyBar can extract from location or notes)
- `isHoliday`
- `hasAlert`
- `travelTimeSeconds`

## Behavior notes

- no access returns an empty snapshot
- birthdays are separated and use the same calendar filters as regular events
- occurrence ids are deterministic even when EventKit omits an event identifier
- relative and absolute alarms are normalized into visible lead times
- EventKit exposes no public event travel-time API; compatibility access is isolated behind an exception-safe Objective-C adapter and invalid values fail closed
- sections are optional, day-bucketed once, and clamp multi-day display times to each section day

## Boundary

The calendar agent collects calendar data and performs calendar mutations.

EasyBar decides how calendar data is rendered.

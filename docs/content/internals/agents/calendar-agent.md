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
- date range is inclusive/exclusive
- filters are applied server-side

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
- birthdays are separated
- travel time is handled explicitly
- sections are optional

## Boundary

The calendar agent collects calendar data and performs calendar mutations.

EasyBar decides how calendar data is rendered.



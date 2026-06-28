# Activity Worklog Suggestions Design

## Purpose

`verstak.activity` already records public plugin events and displays scoped
activity streams. The next roadmap step is to turn that stream into a small,
useful reconstruction layer that can suggest worklog entries without making
Journal a core feature.

## Scope

This slice adds worklog suggestions to the official Activity plugin only.
It does not create the Journal plugin, reports, billing states, manual time
editing, or final worklog persistence. Those remain the next roadmap item.

## Behavior

- Activity reconstructs suggestions from the same normalized events it already
  renders.
- Suggestions are scoped the same way as the Activity view:
  - a workspace Activity view uses only that workspace stream;
  - the global Activity view aggregates all streams and produces suggestions
    per workspace/day.
- Events are grouped by workspace and calendar day using `occurredAt` or
  `receivedAt`.
- Each group produces one suggestion with:
  - stable `suggestionId`;
  - `workspaceRootPath`;
  - `date`;
  - `title`;
  - `summary`;
  - `minutes`;
  - source `eventIds`.
- Estimated time is conservative:
  - one event: 15 minutes;
  - multiple events: time span between first and last event, rounded up to
    15-minute increments;
  - minimum 15 minutes, maximum 480 minutes.

## Runtime Contract

The Activity plugin contributes and registers this command:

```text
verstak.activity.suggestWorklog
```

Arguments:

```json
{
  "workspaceRootPath": "Project"
}
```

`workspaceRootPath` is optional. When omitted, the command returns suggestions
for all available activity streams.

Result:

```json
{
  "suggestions": [
    {
      "suggestionId": "worklog:Project:2026-06-27",
      "workspaceRootPath": "Project",
      "date": "2026-06-27",
      "title": "Project work on 2026-06-27",
      "summary": "Example Article; Saved note",
      "minutes": 30,
      "eventIds": ["capture-1", "note-1"]
    }
  ]
}
```

If the command cannot read settings, it returns an empty suggestions array and
does not throw for normal UI consumption.

## UI

Activity shows a compact suggestions band above the event list when suggestions
exist. The band is informational only in this slice. It exposes stable DOM data
attributes for smoke tests and later Journal wiring:

- `data-activity-section="worklog-suggestions"`
- `data-worklog-suggestion="<suggestionId>"`

## Testing

`scripts/smoke-activity-plugin.js` must verify:

- the manifest requests `commands.register`;
- the manifest declares `verstak.activity.suggestWorklog`;
- Activity registers the command when mounted;
- workspace Activity renders a worklog suggestion for multiple events;
- the command returns the same suggestion shape;
- global Activity groups suggestions by workspace and day;
- clearing Activity clears suggestions.

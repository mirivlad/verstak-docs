# Journal Worklog Plugin Design

## Purpose

Add the first official Journal plugin as a replaceable plugin, not a desktop
core feature. It must give users a visible worklog surface and consume Activity
worklog suggestions through the command runtime added in
`verstak.activity.suggestWorklog`.

## Scope

This slice creates `verstak.journal` with workspace-scoped worklog storage,
manual entry creation, and one-click import from Activity suggestions.
It does not implement billing reports, invoice export, timers, sync-specific
conflict handling, or cross-workspace report aggregation.

## Behavior

- Journal appears as both a sidebar view and a workspace item.
- In a workspace, entries are stored under a workspace settings key.
- In the global view, Journal aggregates entries from every workspace key.
- A manual entry contains:
  - `entryId`;
  - `workspaceRootPath`;
  - `date`;
  - `title`;
  - `summary`;
  - `minutes`;
  - `billable`;
  - optional `sourceSuggestionId`.
- Importing Activity suggestions calls:

```text
api.commands.executeFor(
  'verstak.activity',
  'verstak.activity.suggestWorklog',
  { workspaceRootPath }
)
```

- Imported suggestions become non-billable entries by default.
- Import is idempotent by `sourceSuggestionId`: importing the same Activity
  suggestion twice does not create duplicates.
- If Activity is unavailable, Journal stays usable for manual entries and shows
  a status message.

## Storage

Workspace entries use settings keys:

```text
worklog:workspace:<encoded workspace root>
```

Global aggregation reads all settings keys with the `worklog:workspace:`
prefix.

## Testing

`scripts/smoke-journal-plugin.js` must verify:

- manifest identity, capabilities, optional Activity dependency, and UI
  contributions;
- the Journal view mounts;
- manual entry creation stores and renders an entry;
- Activity import calls the command runtime and stores suggestions as entries;
- importing the same suggestion twice does not duplicate entries;
- global Journal aggregates workspace entries.

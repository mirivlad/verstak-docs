# First Alpha Product UX Design

## Status and scope

This is the approved product-UX tranche for the first public alpha. It covers
the Desktop application, official Activity, Journal and Browser Inbox plugins,
and the browser extension. Release packaging, public repository documentation,
licensing, and sync-server hardening are specified separately in the
`alpha-release` tranche.

The user-visible Russian term is **Дело**. Existing platform and storage names
such as `workspaceRootPath` remain internal compatibility details in this
tranche.

This document supersedes conflicting decisions in the following older narrow
designs:

- `2026-06-29-activity-worklog-suggestions-design.md` for candidate lifecycle
  and background availability;
- `2026-06-29-browser-inbox-domain-binding-design.md` for the relation between
  bindings, global Inbox, and browser activity;
- `2026-07-11-platform-localization-design.md` only where it would leave
  developer-facing plugin IDs visible in the normal user interface.

## Product decisions

- A new Дело is created **only** by an explicit user action. Browser Inbox,
  Activity, and Journal never create a case, candidate case, or implicit case.
- A manual extension send is a Browser Inbox capture. Passive browsing activity
  is never an Inbox capture.
- Passive browser activity records only a normalized hostname and measured
  duration. It never records a page URL, title, selection, page content,
  keystrokes, or browsing history.
- Passive browser activity counts only the active tab in a focused browser
  window. Background tabs and unfocused browser windows contribute no time.
- Activity can suggest a Journal record, but the user reviews and saves it.
  Journal entries are never created automatically.
- An unassigned activity can be saved only after the user picks an existing
  Дело. Picking it for a single Journal entry does not silently create a domain
  binding.
- The first alpha retains one optional Дело assignment per Browser Inbox
  capture, matching current product semantics. It does not introduce sharing a
  capture between several cases.

## Browser extension: manual capture and passive activity

### Manual capture

The existing explicit popup/context-menu actions remain the only way to create
`browser.capture.*` events and Browser Inbox records. Their protocol and
retry queue remain separate from passive activity data.

### Domain activity tracker

The extension adds a small persisted tracker:

1. When an HTTP(S) page becomes the active tab of a focused browser window,
   start timing its normalized lowercase hostname.
2. On tab activation, hostname change, window focus loss, or a five-minute
   alarm, calculate elapsed time and add it to that hostname's local total.
3. Ignore browser-internal pages, invalid URLs, and excluded hostnames. An
   exclusion `youtube.com` matches that hostname and every subdomain; the same
   rule applies to `x.com`.
4. On a flush, send each accumulated hostname as a `browser.activity.domain`
   record. The payload contains a schema version, idempotency ID, observed
   period bounds, hostname, and `durationSeconds`; it contains no URL-like
   field.
5. Remove a hostname's sent total only after Desktop confirms that particular
   idempotency ID. On failure, shutdown, or service-worker suspension, preserve
   the timestamp and totals in extension local storage and retry later.

The extension uses timestamp arithmetic rather than an in-memory interval, so
the behaviour survives Chromium Manifest V3 service-worker restarts. Its
manifest gains only the `windows` and `alarms` permissions needed for this
flow; existing tab access is retained. Firefox uses the equivalent WebExtension
events.

The settings page gets an **Excluded domains** list. It accepts one hostname per
item, normalizes case and leading dots, rejects a scheme/path/query, and
explains that a hostname excludes its subdomains. The default list is empty.

### Desktop receiver

Desktop exposes an authenticated activity receiver separate from the capture
receiver. It validates a bounded hostname, positive bounded duration, ISO time
fields, schema version, and idempotency ID before it publishes
`browser.activity.domain`. Invalid and duplicate records do not enter Activity.
The existing local pairing token gates the endpoint; the token is never placed
in Activity storage or UI.

The receiver annotates a valid activity with an existing exact hostname-to-Дело
binding when one exists. Bindings remain explicit: `client.example.com` does
not imply `example.com` or the reverse. This is deliberately different from
the exclusion-list suffix rule. Unbound activity is stored as global activity.

## Activity and Journal

### Background processing

Official plugins gain a lifecycle-safe background-service contribution. It is
loaded when the plugin host starts, not only while the plugin view is mounted.
The Activity service subscribes once to public events, normalizes and persists
them, rebuilds candidates, and releases subscriptions on host teardown.

The platform provides unsubscribe-capable event subscriptions. Activity writes
use the existing atomic plugin-settings update primitive, preventing concurrent
browser/file events from overwriting each other. Command registration is also
owned by the background service so commands remain available without opening
the Activity view.

### Candidate rules

Activity presents chronological sessions rather than a raw log by default. A
browser activity session displays, for example, `admin.client-site.ru · 1 ч
32 мин`; it exposes no hidden URL/title data.

A candidate is scoped to one existing Дело and local calendar day. It is ready
when either:

- meaningful events in its session cover at least ten minutes and include at
  least two events; or
- it contains one or more browser-domain records totaling at least ten minutes.

`workspace.selected`, `file.opened`, and `note.opened` are diagnostic context,
not meaningful work by themselves. Candidate identity is stable by case, local
day, and source event IDs. Accepted and dismissed state is persisted, so an
already handled candidate does not reappear after a restart.

The Journal review action opens the existing journal editor with candidate
duration, date, and a concise domain/event summary. The user may edit all
content and must explicitly save. For global/unassigned activity, the review
requires choosing one existing Дело first. Missing or disabled Journal support
produces a visible, actionable message rather than failing silently.

Activity has two clear views:

- **Сессии** — default, with candidate cards and activity summaries;
- **События** — a secondary diagnostic stream for technical event inspection.

## Browser Inbox lifecycle

### Record state

A capture remains one canonical record with independent fields:

```text
globalState: active | archived
workspaceRootPath: optional existing Дело
```

Existing records migrate to `globalState: active`; their current assignment is
retained. The current test vault may be discarded, but the migration is
non-destructive for an alpha user vault.

### Actions

- **Assign to Дело** retains the capture in global Inbox and shows it in the
  selected Дело's Inbox.
- **Убрать из общих входящих** changes `globalState` to `archived`. It never
  removes the assignment, so an assigned capture remains available from its
  Дело.
- **Открепить от дела** removes only `workspaceRootPath`. If the capture is
  still globally active it returns to the global Inbox; otherwise it remains in
  archive.
- **Удалить везде** removes the canonical capture and its assignment. It is a
  separate destructive action and requires confirmation that names the affected
  Дело when assigned.
- **Сохранить ссылку в деле** creates an independent `.url` file under the
  case's `Links/` directory, creating that directory first. Success does not
  depend on retaining the capture record; later Inbox deletion cannot remove
  the written file.

Bulk actions operate only on the visibly filtered capture set, show the count,
and use archive rather than permanent deletion. Every permanent deletion and
Journal deletion has a cancellation-safe confirmation dialog.

When a Дело is renamed, the Inbox service migrates its capture assignments and
exact domain bindings from the old root to the new root. It does not migrate a
binding that has been manually changed to another Дело during that operation.

## Alpha interface

- Use Russian product labels consistently: **Дела**, **Входящие**,
  **Активности**, and **Журнал**. User-facing dates use the local time zone.
- The overview contains only useful, properly scoped items: continuation for
  the selected Дело, new Inbox records, Journal candidates, and real recent
  changes. It excludes repeated `file.changed`, `workspace.selected`, and
  unrelated-case events.
- Empty states give a next action, not an empty pane.
- Clear, delete, and archive actions name their scope and consequences.

Plugin IDs are diagnostic information. Normal tabs display the manifest's
human title, such as `Заметки` or `Изображение`, never
`verstak.default-editor.notes-markdown` or `verstak.file-preview.image`.

Add a persisted **Settings → Debug → Show plugin IDs** preference, defaulting
to false. The Desktop application-specific `--debug` command-line argument
enables the same display only for that run. When either is active, show the ID
adjacent to the human title and in diagnostic errors. Neither mode alters data,
plugin permissions, or release behaviour.

## Error handling and privacy

- A failed extension delivery keeps the accumulated hostname time locally and
  reports a non-blocking retry state in extension settings; it never falls back
  to Browser Inbox capture.
- Receiver authentication/validation errors provide a safe status to the
  extension without echoing the pairing token or untrusted payload.
- Activity never manufactures a case from missing assignment data.
- User-visible errors explain the failed action and offer the next safe action.

## Verification

Automated checks must cover:

- browser tracker start/stop, focused-tab-only accounting, exclusions,
  coalescing, acknowledgement-only reset, retry persistence, and payload
  privacy;
- Desktop activity receiver authentication, validation, idempotency, binding,
  and event publication;
- atomic Activity persistence, background subscription lifecycle, candidate
  threshold/state, Journal handoff, local dates, and missing-Journal feedback;
- assigning, archiving, unlinking, permanent deletion, `.url` creation,
  filtered bulk operations, and renaming an assigned Дело;
- normal and debug-mode plugin tab labels;
- the corrected frontend Wails mock, plus the end-to-end flows
  activity-to-Journal and Inbox-to-Дело.

Manual GUI smoke testing verifies Russian normal-mode labels, hidden plugin
IDs, candidate review, Inbox preservation, and extension domain exclusions in
the Linux Desktop build.

## Out of scope

- automatic creation of a Дело;
- background-tab or browser-history tracking;
- URL/content/title collection for passive activity;
- shared/multi-case captures;
- automated Journal saving, billing, or time-sheet generation;
- browser-extension localization and a general analytics product;
- release packaging, licensing, public GitHub README, and sync-server release
  security, which belong to the next alpha-release design.

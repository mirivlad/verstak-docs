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

## Durable identity of a Дело

Every managed Дело has an immutable UUID v4 `workspaceId`. It is the identity for
relations; `workspaceRootPath` is only the current or historical filesystem
address and presentation label. Inbox assignments, domain bindings, Activity
events/sessions/candidates, Journal source references, and Overview state store
`workspaceId` as their primary relation key and retain a path only as a cached
display value.

The UUID lives in a small immutable marker inside the case folder,
`<Дело>/.verstak/workspace.json`, and is also indexed in Desktop metadata. The
inside-folder marker survives a Desktop rename, Trash move, restore, and an
external filesystem rename. It prevents a newly created folder with the same
path from inheriting old links.

On first alpha startup, each writable legacy or externally created top-level
case without a marker receives a new UUID and its path-keyed relation data is
migrated to that UUID. If a folder is not writable, it remains viewable but
cannot be selected as a durable relation target until its marker can be
created. If two active folders contain the same UUID (for example after a
filesystem copy), Desktop shows an identity-repair action and does not
automatically attach Inbox, binding, or Activity data to either duplicate.
The repair UI asks which folder retains the existing identity; it generates a
new marker UUID for the other folder and leaves old relations with the retained
identity. It never silently merges the two folders' histories.

Workspace lifecycle events carry both `workspaceId` and current path. A rename
updates only the path cache. Trash and restore retain the same ID and use the
trash ID only to match the particular trash operation. When a folder is removed
outside Desktop, its relations retain the UUID and become unavailable; a new
folder at the old path has a newly generated UUID and cannot take them over.

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
- Passive browser tracking is disabled on a new installation. It starts only
  after explicit, informed consent in extension settings.
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

Passive tracking is an opt-in extension setting, `passiveActivityEnabled`, with
a default of `false`. The first extension settings view includes a concise
consent card and an unchecked switch. It states that the feature sends only a
normalized hostname and duration, and explicitly states that it does **not**
collect or send URLs, titles, page content, selections, keystrokes, or browser
history. The same explanation remains next to the switch after onboarding.

Until the user enables that switch, the extension does not subscribe to
tracking events, create activity state, or send activity records. Disabling it
stops tracking immediately, clears only the mutable unflushed accumulator, and
leaves already acknowledged Desktop activity unchanged. The user can either
retry or discard already-created pending batches through an explicit settings
action; disabling tracking never silently loses them.

When enabled, the extension uses a persisted tracker:

1. When an HTTP(S) page becomes the active tab of a focused browser window,
   start timing its normalized lowercase hostname.
2. On tab activation, hostname change, window focus loss, browser idle/lock,
   or a five-minute alarm, write a checkpoint and calculate elapsed time. The
   idle detection threshold is explicitly ten minutes; a locked state pauses
   immediately.
3. Ignore browser-internal pages, invalid URLs, and excluded hostnames. An
   exclusion `youtube.com` matches that hostname and every subdomain; the same
   rule applies to `x.com`.
4. On a flush, freeze one record per hostname as a `browser.activity.domain`
   batch. The payload contains a schema version, idempotency ID, observed
   period bounds, hostname, and `durationSeconds`; it contains no URL-like
   field.

The persisted state has three distinct parts:

```text
activeAccumulator: mutable, unsent duration and bounds by hostname
pendingBatches:    immutable payloads, keyed by idempotency ID
acknowledgedIds:   bounded recent acknowledgement IDs
```

Flushing copies a hostname's current accumulator into a new immutable pending
batch with a newly generated ID, then clears only that copied accumulator. New
time for the same hostname accumulates in `activeAccumulator` and can become a
later batch. It never mutates an already sent batch. Retries send the stored
payload byte-for-byte. A successful acknowledgement removes only the matching
pending batch and records its ID; it cannot remove newer time. Pending batches
are sent oldest first. `acknowledgedIds` is a 30-day bounded LRU set used to
handle replayed acknowledgement messages safely; Desktop maintains its own
idempotency store as the authority.

The tracker uses timestamp arithmetic but applies a conservative ambiguity
limit. A checkpoint contributes elapsed time only if wall-clock time is
monotonic and the gap from the previous trustworthy checkpoint is no more than
ten minutes. A negative clock delta, a gap over ten minutes, an idle/locked
state, or a browser startup after a crash discards the ambiguous interval and
establishes a fresh baseline. WebExtensions have no portable system
suspend/resume event, so the first post-suspend observation is deliberately
handled by this gap rule; platform idle/lock events add an earlier pause where
available. This can undercount ambiguous work but cannot turn an overnight
sleep or a clock change into working time. A browser startup never carries an
active interval across process death; pending batches and accumulated completed
intervals are retained.

The extension persists timestamps and the three state parts in local extension
storage, so a Manifest V3 service-worker restart can continue safely. It sets
the `idle` API detection interval to ten minutes. Its manifest gains the
`windows`, `alarms`, and `idle` permissions needed for this flow; existing tab
access is retained. Firefox uses the equivalent WebExtension events when
available and otherwise applies the same ten-minute checkpoint limit.

The settings page gets an **Excluded domains** list. It accepts one hostname per
item through the canonical normalization below, and explains that a hostname
excludes its subdomains. The default list is empty. Adding an exclusion stops
the matching active measurement immediately and discards only its mutable
unflushed time; immutable pending batches remain available for the user's
explicit retry or discard decision.

### Canonical hostname normalization

Every extension event, exclusion, and Desktop domain binding uses
`hostname-normalization-v1`. It is a normative shared contract, not an
implementation detail of one component:

1. An activity source must be an HTTP(S) URL. Its port, user info, path, query,
   and fragment are discarded before hostname normalization. A binding or
   exclusion must be a bare hostname; schemes, paths, queries, fragments, and
   ports are rejected.
2. Trim surrounding whitespace, lowercase, and remove exactly one DNS root
   trailing dot. `example.com.` therefore becomes `example.com`.
3. Convert DNS names using non-transitional UTS #46 / IDNA lookup processing to
   an ASCII A-label. The canonical stored and compared form of `пример.рф` is
   its punycode A-label; the settings UI may render the Unicode display form.
4. IPv4 addresses are accepted in canonical dotted-decimal form. IPv6 literals
   are accepted (bracketed only at URL/settings input), stored without brackets
   in canonical lower-case RFC 5952 form, and never include a port. `localhost`
   and syntactically valid single-label internal names are also accepted.
5. Reject empty values, malformed IP literals, invalid labels, empty labels,
   labels over 63 ASCII bytes, DNS names over 253 ASCII bytes, and any input
   that fails URL/IDNA parsing. Invalid activity is not counted; invalid
   settings input gets an inline validation error and is not saved.

The SDK owns a versioned `hostname-normalization-v1` test-vector corpus. Desktop
and the browser extension vendor the byte-identical corpus in their tests; the
coordinated `build-all` verification checks its hash. Go and JavaScript have
separate implementations, but both must pass every vector, including trailing
dots, Unicode/punycode equivalence, IPv4, IPv6, localhost, internal names,
ports, malformed input, and excessive lengths.

### Desktop receiver

Desktop exposes an authenticated activity receiver separate from the capture
receiver. It normalizes and validates a hostname with
`hostname-normalization-v1`, validates a positive bounded duration, ISO time
fields, schema version, and idempotency ID before it publishes
`browser.activity.domain`. Invalid and duplicate records do not enter Activity.
The existing local pairing token gates the endpoint; the token is never placed
in Activity storage or UI.

The receiver annotates a valid activity with an existing exact hostname-to-Дело
binding when one exists. A binding stores `workspaceId` as identity and the
current root path as display cache. Bindings remain explicit:
`client.example.com` does not imply `example.com` or the reverse. This is
deliberately different from the exclusion-list suffix rule. Unbound activity is
stored with the explicit `unassigned` session scope.

## Activity and Journal

### Background processing

Official plugins gain a lifecycle-safe background-service contribution. It is
loaded when the plugin host starts, not only while the plugin view is mounted.
The Activity service subscribes once to public events, normalizes and persists
them, rebuilds candidates, and releases subscriptions on host teardown.

The platform provides unsubscribe-capable event subscriptions. Command
registration is owned by the background service so commands remain available
without opening the Activity view.

Raw Activity data is not held in `settings.json`. The Desktop storage layer
provides a lifecycle-safe, plugin-scoped append-only event log for
`verstak.activity` under plugin data. Appending one event does not rewrite the
whole log. Plugin settings retain only compact preferences; plugin data retains
candidate watermarks and indexes. Appends and compaction are serialized by the
storage layer, preventing lost updates.

### Candidate rules

Activity presents chronological sessions rather than a raw log by default. A
browser activity session displays, for example, `admin.client-site.ru · 1 ч
32 мин`; it exposes no hidden URL/title data.

A logical session has one explicit scope:

```text
{ kind: "workspace", workspaceId, workspaceRootPath } | { kind: "unassigned" }
```

An unassigned session is a normal temporal scope, not an exception. It is shown
in Activity and may open Journal review, where the user must choose an existing
active Дело. That one-time choice does not create a binding. A workspace session
is split only by a different workspace ID, a transition to/from unassigned, a
20-minute idle gap, or 120 minutes of total session span. It is not split
merely because midnight passes. A session is ready when either:

- meaningful events in its session cover at least ten minutes and include at
  least two events; or
- it contains one or more browser-domain records totaling at least ten minutes.

`workspace.selected`, `file.opened`, and `note.opened` are diagnostic context,
not meaningful work by themselves.

Duration is normative rather than the wall-clock span from first to last event.
Sort meaningful events by `{occurredAt, activityId}` within a session:

- A browser-domain record contributes its explicit validated
  `durationSeconds`.
- A file/note event has no inherent duration. For each adjacent pair of
  zero-duration meaningful events, add `min(time difference, 10 minutes)` only
  when no explicit-duration browser record lies between that pair in the
  ordered session.
- A gap over 20 minutes has already split the session, so it contributes no
  implicit duration. The first and final standalone point event each contribute
  zero seconds.
- Candidate duration is the sum of explicit browser duration and these implicit
  point-event intervals, capped at the 120-minute session maximum. It is never
  inferred from the overall first-to-last span.

Thus a note saved at 10:00 and a file changed at 10:09 estimate nine minutes;
the same events at 10:00 and 10:50 form separate zero-duration sessions rather
than a fictional 50-minute block.

Each logical session receives a newly generated immutable UUID `sessionId` at
creation and stores an immutable anchor `{scope, firstSeenAt, firstActivityId}`.
The service stores that ID on each appended event and preserves the anchor
through log compaction. A late event may join a same-scope session only when it
falls within that session's 20-minute boundary; otherwise it starts a new
session. It never recomputes an existing session ID or anchor. Each session
persists an ordered handled watermark
`{ occurredAt, activityId }` and optional state for the latest reviewed slice.
A candidate contains only source events after that watermark:

- **Accepting** a candidate stores its `sessionId` and handled watermark on the
  Journal entry. Later activity can create a candidate only for the additional
  interval after that watermark and only when that new interval reaches the
  normal threshold.
- **Dismissing** consumes the current candidate slice through its watermark.
  `A+B` therefore cannot reappear as `A+B+C`; only qualifying new work after
  `B` may later be suggested.
- A dismissal is not a permanent ban on future work in the same logical
  session. At least ten new meaningful minutes are required before it can be
  suggested again.

An event arriving late at or before a handled watermark remains in the raw
diagnostic log but never reopens an accepted or dismissed candidate slice.

An across-midnight logical session remains one candidate. The review displays
its time apportioned by local date, preselects the date containing the largest
share of the duration (ties use the start date), and lets the user choose the
Journal date. This preserves a 23:50–00:30 session instead of losing its first
ten minutes to an artificial threshold.

The Journal review action opens the existing journal editor with candidate
duration, date, and a concise domain/event summary. The user may edit all
content and must explicitly save. For global/unassigned activity, the review
requires choosing one existing Дело first. Missing or disabled Journal support
produces a visible, actionable message rather than failing silently.

Activity has two clear views:

- **Сессии** — default, with candidate cards and activity summaries;
- **События** — a secondary diagnostic stream for technical event inspection.

### Retention and deletion

The alpha retains raw Activity events for at most 60 days, 10,000 events, or
8 MiB of log data, whichever limit is reached first. On append and at service
startup, bounded compaction removes the oldest entries until all limits hold;
it does not block the UI. Candidate state is pruned once its session and every
related Journal source watermark are older than 60 days.

Saving a Journal entry does not delete its source Activity events. The Journal
entry retains the compact source session/watermark reference after raw-event
retention removes those events. **Clear activity for this Дело** removes only
that case's raw events, sessions, and candidate state after confirmation.
**Clear all activity** is a separate global confirmed operation.

## Browser Inbox lifecycle

### Record state

A capture remains one canonical record with independent fields:

```text
globalState: active | archived
workspaceId: optional immutable UUID of assigned Дело
workspaceState: unassigned | active | trashed | unavailable | orphaned
workspaceRootPath: optional current or historical Дело path cache
workspaceTrashId: optional stable trash identity
```

Existing records migrate to `globalState: active`. An assignment whose current
path resolves to an active marker receives that marker's `workspaceId`; an
unresolved legacy path becomes `unavailable` rather than attaching to a future
folder of the same name. The current test vault may be discarded, but the
migration is non-destructive for an alpha user vault.

### Actions

- **Assign to Дело** retains the capture in global Inbox and shows it in the
  selected Дело's Inbox.
- **Убрать из общих входящих** changes `globalState` to `archived`. It never
  removes the assignment, so an assigned capture remains available from its
  Дело.
- **Открепить от дела** clears `workspaceId`, `workspaceRootPath`, and
  `workspaceTrashId`, and sets `workspaceState` to `unassigned`. If the capture is
  still globally active it returns to the global Inbox; otherwise it remains in
  archive.
- **Удалить везде** removes the canonical capture and its assignment. It is a
  separate destructive action and requires confirmation that names the affected
  Дело when assigned.
- **Сохранить ссылку в деле** is available only for a valid HTTP(S) capture URL.
  It opens a small save dialog with an editable proposed filename derived from
  the capture title, then its hostname, then `Link`. The stem is sanitized for
  cross-platform forbidden characters and control characters, limited to 96
  characters, and receives `.url`. The file uses InternetShortcut format and
  is created through the plugin `files.write` capability under the case's
  `Links/` directory, creating that directory first. A name collision never
  overwrites silently: the dialog offers an explicit `name (2).url` alternative
  or cancellation. Read-only/error cases leave the capture unchanged and show
  the failure. Success publishes the normal safe file/link Activity event; the
  link is opened through the dedicated URL-opening behaviour below, not by
  relying on a Linux `.url` file association.

Bulk actions operate only on the visibly filtered capture set, show the count,
and use archive rather than permanent deletion. Every permanent deletion and
Journal deletion has a cancellation-safe confirmation dialog.

When a Дело is renamed, the Inbox service updates the path cache of captures
and exact domain bindings with that `workspaceId`; no relation is keyed by the
old root path. It does not update a binding that has been manually changed to a
different workspace ID during that operation.

When a Дело goes to Trash, assignments and bindings for its `workspaceId`
become `trashed` with the Desktop trash ID. They remain visible as unavailable
historical context but are not used for automatic routing. A restore event
carrying that trash ID restores the same ID's assignment/binding, including a
restored path changed by a collision. A permanent trash purge changes captures
to unassigned and changes bindings to a visible `orphaned` state that the user
can reassign or remove. Activity remains historical and labels the case as
deleted. If a case disappears by external filesystem change, active references
become `unavailable`, automatic routing is disabled, and the user must
explicitly reassign or remove them; a newly created folder with the same name
has a different `workspaceId` and never steals those references.

### Archive and filters

Global Browser Inbox has **Active**, **Archive**, and **All** status filters;
Active is the default. Search applies within the chosen filter, so Archive is
searchable deliberately through Archive or All rather than unexpectedly
appearing in the normal queue. **Restore to Inbox** changes `globalState` back
to `active`. Archive supports a visible filtered bulk restore with a count and
confirmation. A capture assigned to a Дело remains visible in that Дело's Inbox
regardless of its global archive state, with an Archive badge.

### Opening saved links on Linux

The platform adds a user-initiated `urls.openExternal` capability and API. It
accepts only a validated HTTP(S) URL and opens that URL through the system
browser opener (`xdg-open` in the Linux alpha); it never passes a `.url` file
path to the opener. Browser Inbox uses this capability for **Open link** and
for a saved `.url` after parsing and validating its `URL=` value. The Files
surface recognizes a valid `.url` file and uses the same URL-opening path. This
does not depend on desktop file-association support for InternetShortcut files.

## Alpha interface

- Use Russian product labels consistently: **Дела**, **Входящие**,
  **Активности**, and **Журнал**. User-facing dates use the local time zone.
- With a selected Дело, the overview reads only records explicitly scoped to
  that Дело; an unscoped global event never leaks into every case. With no
  selected Дело, it shows a short prompt to select/create one plus up to five
  active unassigned Inbox records; it does not fabricate a blended continuation
  feed.
- **Needs attention** shows at most five entries: ready Journal candidates,
  active unprocessed Inbox records, and existing urgent Todos, in that order
  within their respective priority. An Inbox record is new/needs attention
  while it is active and unprocessed, without an arbitrary age cutoff.
- Todo rows are included only when a loaded plugin exposes the `todo.workspace`
  capability. A missing or disabled Todo plugin is not an Overview error and
  contributes no placeholder rows.
- **Continue work** shows at most four distinct case-scoped entities from the
  last 14 days: unfinished Todo, unprocessed capture, and the most recent
  note/file/Journal entity. Every item carries `lastMeaningfulAt`; items sort
  descending by that value, with an unprocessed capture, Todo, Journal, note,
  then file as deterministic ties. Multiple `file.changed` events for the same
  entity collapse to one item. Opening an item does not mark it complete. Its
  overflow action **Hide recommendation** stores a non-destructive
  entity/event dismissal; a later meaningful change to that entity makes it
  eligible again.
- **Recent changes** shows at most eight distinct case-scoped records from the
  last seven days. Included events are note save/create, file create/rename or
  last change per file, saved browser link, and Journal create. Technical
  selection/open events are excluded. The empty state says that there were no
  changes in that period.
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
  reports the pending-batch count and a non-blocking retry state in extension
  settings; it never falls back to Browser Inbox capture.
- Receiver authentication/validation errors provide a safe status to the
  extension without echoing the pairing token or untrusted payload.
- Activity never manufactures a case from missing assignment data.
- User-visible errors explain the failed action and offer the next safe action.

## Verification

Automated checks must cover:

- browser tracker explicit consent/disable behaviour, focused-tab-only
  accounting, exclusions, canonical hostname vectors, immutable pending
  batches, acknowledgement-only reset, retry persistence, payload privacy,
  negative clock changes, long gaps, restart, lock, and suspend/resume;
- Desktop activity receiver authentication, canonical normalization,
  validation, idempotency, binding, and event publication;
- append-only Activity log retention/compaction, background subscription
  lifecycle, UUID workspace/unassigned session scopes, point-event duration
  calculation, immutable session IDs/late events, handled watermarks,
  across-midnight review, Journal handoff, local dates, case-scoped clear, and
  missing-Journal feedback;
- assigning, archiving, restoring, unlinking, permanent deletion, `.url`
  naming/collision/readonly behaviour, filtered bulk operations, rename, trash
  restore/purge, external-workspace unavailability, duplicate-workspace-ID
  repair, and direct Linux URL opening without `.url` association;
- normal and debug-mode plugin tab labels;
- the corrected frontend Wails mock, deterministic Overview limits/scoping,
  plus the end-to-end flows activity-to-Journal and Inbox-to-Дело.

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

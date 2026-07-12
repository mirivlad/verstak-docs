# Alpha Activity And Journal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Make Activity a durable, background-maintained session log that safely proposes Journal entries without creating a Дело automatically.

**Architecture:** Desktop adds a plugin background-service lifecycle, unsubscribe-capable event bridge, and append-only Activity log. The Activity plugin owns session reconstruction and watermarks; Journal receives an explicit reviewed candidate and requires a destination for unassigned sessions.

**Tech Stack:** Go, Wails, Svelte, plain JavaScript plugin bundles, Go tests, Node smoke tests, Playwright.

## Global Constraints

- Activity raw events are retained for 60 days, 10,000 events, or 8 MiB, whichever is reached first.
- Raw activity uses append/compaction, not settings.json rewrites.
- Session scope is workspaceId plus path cache or unassigned.
- Point-event duration is capped at 10 minutes per adjacent pair; gap over 20 minutes starts another session.
- Accepted/dismissed watermarks consume only the reviewed slice.
- Journal save is always an explicit user action.

---

### Task 1: Add background services, event unsubscription, and an append-only Activity log

**Files:**
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/plugin/plugin.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/plugin/plugin_test.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/events/bus.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/api/app.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/api/app_test.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/storage/api.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/storage/api_test.go
- Create: /home/mirivlad/git/verstak2/verstak-desktop/frontend/src/lib/plugin-host/BackgroundPluginHost.svelte
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/src/App.svelte
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/src/lib/plugin-host/VerstakPluginAPI.js
- Modify: /home/mirivlad/git/verstak2/verstak-sdk/src/types.ts
- Modify: /home/mirivlad/git/verstak2/verstak-sdk/schemas/contributions.json
- Modify: /home/mirivlad/git/verstak2/verstak-sdk/schemas/manifest.json
- Modify: /home/mirivlad/git/verstak2/verstak-sdk/src/plugin-api.test.ts

**Interfaces:**
- Adds contributes.backgroundServices with id and component fields.
- Bus Subscribe returns subscription ID; Unsubscribe removes only that handler.
- Adds ActivityLogAppend, ActivityLogRead, ActivityLogDeleteWorkspace, and ActivityLogCompact backend methods.
- Background bundle registration exposes start(api) returning a cleanup function.

- [ ] **Step 1: Write failing manifest, bus, and storage tests**

Add a manifest validation test and isolated bus-unsubscribe test:

~~~go
subA := bus.Subscribe("browser.activity.domain", handlerA)
subB := bus.Subscribe("browser.activity.domain", handlerB)
bus.Unsubscribe("browser.activity.domain", subA)
bus.Publish(events.Event{Name: "browser.activity.domain"})
if gotA != 0 || gotB != 1 { t.Fatalf("wrong selective unsubscribe: %d %d", gotA, gotB) }
~~~

Add an append test asserting two appends create two NDJSON records and a
compaction test keeping only the newest record under a small test limit.

- [ ] **Step 2: Run red**

Run:

~~~bash
cd /home/mirivlad/git/verstak2/verstak-desktop
GOCACHE=/tmp/verstak-go-cache go test ./internal/core/plugin ./internal/core/events ./internal/core/storage ./internal/api -run 'Test.*(Background|Unsubscribe|ActivityLog)' -count=1
~~~

Expected: FAIL because subscriptions have no IDs and the log API does not exist.

- [ ] **Step 3: Implement the platform boundary**

Define:

~~~go
type ContributionBackgroundService struct {
    ID        string `json:"id"`
    Component string `json:"component"`
}

type ActivityLogRecord struct {
    ActivityID string          `json:"activityId"`
    Payload    json.RawMessage `json:"payload"`
}
~~~

Append NDJSON under plugin-data/verstak.activity/events.ndjson using a locked
append. Compact to the declared retention limits by rewriting a temporary file.
Keep only compact candidate state in plugin data. BackgroundPluginHost loads
enabled plugins with a background contribution once at app startup and calls the
registered start function; it calls cleanup on disable/reload/destroy.

- [ ] **Step 4: Run green and commit**

Run:

~~~bash
GOCACHE=/tmp/verstak-go-cache go test ./internal/core/plugin ./internal/core/events ./internal/core/storage ./internal/api -count=1
git add internal/core/plugin internal/core/events internal/core/storage internal/api frontend/src/App.svelte frontend/src/lib/plugin-host
git commit -m "feat: add background activity runtime"
git -C /home/mirivlad/git/verstak2/verstak-sdk add src/types.ts schemas/contributions.json schemas/manifest.json src/plugin-api.test.ts
git -C /home/mirivlad/git/verstak2/verstak-sdk commit -m "feat: define plugin background services"
~~~

Expected: focused tests prove one subscription, selective cleanup, append, and compaction.

### Task 2: Rebuild Activity sessions and persistent candidate watermarks

**Files:**
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/plugins/activity/plugin.json
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/plugins/activity/frontend/src/index.js
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/plugins/activity/locales/en.json
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/plugins/activity/locales/ru.json
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/scripts/smoke-activity-plugin.js

**Interfaces:**
- Activity background service registers ActivityService.start(api).
- Event record includes activityId, scope, occurredAt, durationSeconds, and sessionId.
- Candidate contains sessionId, handledThrough, estimatedMinutes, dateSlices, and source activities.

- [ ] **Step 1: Write failing smoke scenarios**

Add three explicit scenarios:

~~~js
const nineMinutes = eventsAt('2026-07-12T10:00:00Z', '2026-07-12T10:09:00Z');
assert.equal(buildSessions(nineMinutes)[0].estimatedMinutes, 9);
const late = appendLateEvent(existingSession, eventAt('2026-07-12T09:58:00Z'));
assert.equal(late.sessionId, existingSession.sessionId);
assert.equal(candidateAfterDismiss.sourceActivityIds.includes('a'), false);
~~~

Also assert a 23:50 to 00:30 session has one session ID and date slices for both
local dates.

- [ ] **Step 2: Run red**

Run:

~~~bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins
node scripts/smoke-activity-plugin.js
~~~

Expected: FAIL because Activity derives candidate IDs from first and last events.

- [ ] **Step 3: Implement background session state**

Replace view-mounted event recording with ActivityService.start(api). Persist
immutable generated session IDs and anchors in activity-state.json. Build scope
as either workspaceId plus root path or unassigned. Sum explicit browser
duration and only zero-duration adjacent point intervals, cap a point interval
at 10 minutes, split at 20 minutes, and cap a session at 120 minutes.

For accept or dismiss, store the ordered handledThrough watermark. New events
after the watermark require another 10 minutes before a new candidate appears;
late events at or before the watermark remain diagnostic only.

- [ ] **Step 4: Run green and commit**

Run:

~~~bash
node scripts/smoke-activity-plugin.js
./scripts/check.sh
git add plugins/activity scripts/smoke-activity-plugin.js
git commit -m "feat: persist activity sessions and watermarks"
~~~

Expected: session, late-event, dismissal, browser-duration, and midnight smoke tests pass.

### Task 3: Review candidates safely in Journal and expose sessions in UI

**Files:**
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/plugins/activity/frontend/src/index.js
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/plugins/journal/frontend/src/index.js
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/plugins/journal/locales/en.json
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/plugins/journal/locales/ru.json
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/scripts/smoke-journal-plugin.js
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/e2e/activity.spec.js
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/e2e/todo.spec.js
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/src/lib/test/wails-mock.js

**Interfaces:**
- Journal candidate request accepts destinationWorkspaceId only for unassigned scope.
- Saved Journal entry stores sourceSessionId and handledThrough in addition to activity IDs.
- Activity UI has Sessions default and Events diagnostic view.

- [ ] **Step 1: Write failing E2E and smoke assertions**

Require an unassigned candidate to show a destination selector and reject Save
until an active workspace ID is selected:

~~~js
await page.getByRole('button', { name: /review/i }).click();
await expect(page.getByText(/choose.*дело/i)).toBeVisible();
await expect(page.getByRole('button', { name: /save/i })).toBeDisabled();
~~~

Require the mock WritePluginSetting path to retain sourceSessionId after reload.
Require Clear Activity and Journal Delete to show cancellation-safe confirmation
before changing stored rows.

- [ ] **Step 2: Run red**

Run:

~~~bash
cd /home/mirivlad/git/verstak2/verstak-desktop/frontend
npm run test:e2e -- activity.spec.js todo.spec.js
~~~

Expected: FAIL because the current mock discards settings and Journal only accepts path-scoped candidates.

- [ ] **Step 3: Implement review UI and local dates**

Render domain rows as hostname plus duration without URLs. Keep raw event
details in the Events tab. For unassigned scope, list active workspace IDs and
require a selection before handing the candidate to Journal. Preselect the
largest date slice, show both date slices, use local date conversion, and save
the session watermark with the Journal entry. Show a visible action if Journal
is disabled instead of silently dropping the request. Put a confirm/cancel
dialog in front of Clear Activity and Journal Delete; cancelling leaves the
append log, candidate state, and entry list untouched.

- [ ] **Step 4: Run green and commit**

Run:

~~~bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins && node scripts/smoke-activity-plugin.js && node scripts/smoke-journal-plugin.js
cd /home/mirivlad/git/verstak2/verstak-desktop/frontend && npm run test:e2e -- activity.spec.js todo.spec.js
git -C /home/mirivlad/git/verstak2/verstak-official-plugins add plugins/activity plugins/journal scripts/smoke-activity-plugin.js scripts/smoke-journal-plugin.js
git -C /home/mirivlad/git/verstak2/verstak-official-plugins commit -m "feat: review activity sessions in journal"
git -C /home/mirivlad/git/verstak2/verstak-desktop add frontend/e2e/activity.spec.js frontend/e2e/todo.spec.js frontend/src/lib/test/wails-mock.js
git -C /home/mirivlad/git/verstak2/verstak-desktop commit -m "test: cover activity journal review flow"
~~~

Expected: candidate-to-Journal, local date, and persisted mock workflows pass.

# Alpha Shell UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Make the Desktop overview scoped and actionable, hide diagnostic plugin IDs by default, and remove alpha UI strings that expose implementation noise.

**Architecture:** The shell consumes stable workspace IDs and plugin capabilities rather than hard-coded namespaces. Overview builds deterministic case-scoped projections; debug display is a presentation preference plus a session-only command-line override.

**Tech Stack:** Svelte, Wails app settings, Go tests, Playwright E2E, existing i18n catalogs.

## Global Constraints

- Default UI labels are Russian and use Дела, Входящие, Активности, Журнал.
- A normal tab never shows a plugin ID.
- Settings Debug Show plugin IDs defaults false; Desktop --debug enables it only for that run.
- Overview never leaks an unscoped event into every case.
- Todo entries are included only if todo.workspace capability is loaded.
- No action opens or creates a Дело implicitly.

---

### Task 1: Add effective debug display setting and human plugin tab labels

**Files:**
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/main.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/appsettings/manager.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/appsettings/manager_test.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/api/app.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/api/app_test.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/src/lib/shell/WorkspaceHost.svelte
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/src/lib/plugin-manager/PluginManager.svelte
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/src/lib/i18n/catalogs/en.js
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/src/lib/i18n/catalogs/ru.js
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/e2e/plugin-api-bridge.spec.js

**Interfaces:**
- Persisted app setting showPluginIds bool defaults false.
- GetAppSettings returns effectiveShowPluginIds and UpdateAppSettings accepts showPluginIds.
- Runtime --debug sets effectiveShowPluginIds true without persisting it.

- [ ] **Step 1: Write failing app-setting and E2E tests**

Add a Go test proving the setting preserves theme and language, plus a browser
test proving normal mode has no raw ID and debug mode has one:

~~~js
await expect(page.locator('[role="tab"]').filter({ hasText: 'verstak.' })).toHaveCount(0);
await mockAppSettings({ showPluginIds: true });
await expect(page.locator('[role="tab"]').filter({ hasText: 'verstak.default-editor' })).toHaveCount(1);
~~~

- [ ] **Step 2: Run red**

Run:

~~~bash
cd /home/mirivlad/git/verstak2/verstak-desktop
GOCACHE=/tmp/verstak-go-cache go test ./internal/core/appsettings ./internal/api -run 'Test.*PluginIds' -count=1
cd frontend && npm run test:e2e -- plugin-api-bridge.spec.js
~~~

Expected: FAIL because no display preference exists.

- [ ] **Step 3: Implement presentation-only debug state**

Parse --debug before Wails startup and keep it in App runtime state. Merge it
with the persisted bool when returning effective settings. Render the localized
manifest title normally; append the plugin ID only when effectiveShowPluginIds
is true. Add the Debug settings checkbox and localized explanatory copy.

- [ ] **Step 4: Run green and commit**

Run:

~~~bash
GOCACHE=/tmp/verstak-go-cache go test ./internal/core/appsettings ./internal/api -count=1
cd frontend && npm run test:e2e -- plugin-api-bridge.spec.js
git add main.go internal/core/appsettings internal/api frontend/src frontend/e2e/plugin-api-bridge.spec.js
git commit -m "feat: hide plugin IDs outside debug mode"
~~~

Expected: normal and debug labels are both verified.

### Task 2: Implement deterministic case-scoped Overview

**Files:**
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/src/lib/shell/TodaySurface.svelte
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/src/lib/shell/WorkspaceHost.svelte
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/src/lib/i18n/catalogs/en.js
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/src/lib/i18n/catalogs/ru.js
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/e2e/ux-today.spec.js
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/e2e/ux-p0.spec.js
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/src/lib/test/wails-mock.js

**Interfaces:**
- Every overview row has workspaceId and lastMeaningfulAt.
- Needs attention maximum is five; Continue work maximum is four; Recent changes maximum is eight.
- Hidden recommendation state is keyed by entity ID and invalidated by later meaningful change.

- [ ] **Step 1: Write failing scope and ranking tests**

Add fixture events for two workspace IDs plus an unscoped event:

~~~js
await seedOverview({
  selectedWorkspaceId: 'client-a',
  events: [
    { activityId: 'a', workspaceId: 'client-a', type: 'note.saved', occurredAt: now },
    { activityId: 'b', workspaceId: 'client-b', type: 'file.changed', occurredAt: now },
    { activityId: 'global', type: 'workspace.selected', occurredAt: now }
  ]
});
await expect(page.getByText(/client-b/i)).toHaveCount(0);
await expect(page.locator('[data-overview-section="continue"] [data-overview-item]')).toHaveCount(4);
~~~

Also assert no selection shows only the select/create prompt and up to five
unassigned active Inbox captures.

- [ ] **Step 2: Run red**

Run:

~~~bash
cd /home/mirivlad/git/verstak2/verstak-desktop/frontend
npm run test:e2e -- ux-today.spec.js ux-p0.spec.js
~~~

Expected: FAIL because rowsFor currently accepts untagged events for every workspace.

- [ ] **Step 3: Implement exact overview projections**

Replace path-only filtering with workspaceId equality. Build:

1. Needs attention: ready Journal candidates, active unprocessed captures, then
   urgent Todo rows only if todo.workspace capability exists; take five.
2. Continue work: distinct entities updated in 14 days; sort by
   lastMeaningfulAt descending and the documented type tie-break; take four.
3. Recent changes: note save/create, file create/rename or last change per
   file, saved link, and Journal create in seven days; take eight.

Persist Hide recommendation without changing underlying data. Use localized
empty states and remove English technical strings.

- [ ] **Step 4: Run green and commit**

Run:

~~~bash
npm run test:e2e -- ux-today.spec.js ux-p0.spec.js
git add src/lib/shell/TodaySurface.svelte src/lib/shell/WorkspaceHost.svelte src/lib/i18n frontend/e2e/ux-today.spec.js frontend/e2e/ux-p0.spec.js src/lib/test/wails-mock.js
git commit -m "feat: make overview case-scoped and actionable"
~~~

Expected: limits, scope, empty state, and recommendation hide tests pass.

### Task 3: Verify alpha UX as a user sees it

**Files:**
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/e2e/ux-followup.spec.js
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/scripts/check-gui.sh

**Interfaces:**
- E2E fixture uses effectiveShowPluginIds false by default.
- GUI checker accepts a --debug-labels case.

- [ ] **Step 1: Write the final failing alpha scenarios**

Add a scenario that creates a capture, assigns it, archives it globally, opens
the assigned case, and verifies the capture is still present. Add a session
candidate path to Journal and assert normal tab labels are human-readable.

~~~js
await archiveGlobalCapture('capture-1');
await openWorkspace('client-a');
await expect(page.getByTestId('browser-capture-capture-1')).toBeVisible();
await expect(page.getByRole('tab', { name: /verstak\./i })).toHaveCount(0);
~~~

- [ ] **Step 2: Run red**

Run:

~~~bash
npm run test:e2e -- ux-followup.spec.js
~~~

Expected: FAIL until the prior plans are integrated.

- [ ] **Step 3: Add deterministic GUI smoke commands**

Extend check-gui.sh to start an isolated test vault, run normal and --debug
screens, and save screenshots under frontend/e2e-results. The script must not
read or mutate the user's normal vault.

- [ ] **Step 4: Run green and commit**

Run:

~~~bash
npm run test:e2e -- ux-followup.spec.js
GOCACHE=/tmp/verstak-go-cache ./scripts/check-gui.sh
git add frontend/e2e/ux-followup.spec.js scripts/check-gui.sh
git commit -m "test: cover first alpha UX smoke flow"
~~~

Expected: E2E and isolated GUI smoke pass.

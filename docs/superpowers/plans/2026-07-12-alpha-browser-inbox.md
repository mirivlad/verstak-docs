# Alpha Browser Inbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Preserve a manually captured link when it leaves the global Inbox, give Browser Inbox a usable archive, and make links durable across case lifecycle changes.

**Architecture:** A capture remains one canonical record. Its global archive state is independent of its workspaceId relation; domain bindings use the same stable identity. Browser Inbox owns capture UI and migration, while Desktop exposes a narrow URL-open capability for user-initiated links.

**Tech Stack:** Plain JavaScript plugin bundle, Go Wails API, Node smoke tests, Playwright.

## Global Constraints

- Only manual extension actions create Browser Inbox captures.
- Captures have at most one optional case assignment in this alpha.
- Remove from global Inbox archives; only Delete everywhere is permanent.
- Assignment and binding use workspaceId, never path as identity.
- Create .url files through files.write and never overwrite a name silently.
- URL opening is direct HTTP(S) opening, not a Linux .url association.

---

### Task 1: Migrate Browser Inbox records and implement archive state

**Files:**
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/plugins/browser-inbox/frontend/src/index.js
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/plugins/browser-inbox/locales/en.json
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/plugins/browser-inbox/locales/ru.json
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/scripts/smoke-browser-inbox-plugin.js
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/api/app.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/api/app_test.go

**Interfaces:**
- Canonical capture fields: globalState, workspaceId, workspaceState, workspaceRootPath, workspaceTrashId.
- Domain binding value: workspaceId plus workspaceRootPath cache plus state.
- Mutations: archive, restore, assign, unassign, deleteEverywhere, migrate.

- [ ] **Step 1: Write failing migration and archive smoke tests**

Use a legacy path assignment and assert it resolves to a stable ID. Test the
original data-loss regression:

~~~js
await inbox.assignWorkspace('capture-1', activeWorkspace);
await inbox.archiveCapture('capture-1');
assert.equal(globalRows().some(row => row.captureId === 'capture-1'), false);
assert.equal(workspaceRows(activeWorkspace.workspaceId).some(row => row.captureId === 'capture-1'), true);
await inbox.restoreCapture('capture-1');
assert.equal(globalRows().some(row => row.captureId === 'capture-1'), true);
~~~

- [ ] **Step 2: Run red**

Run:

~~~bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins
node scripts/smoke-browser-inbox-plugin.js
~~~

Expected: FAIL because archive and assignment are currently one mutable path field.

- [ ] **Step 3: Implement canonical state and idempotent migration**

Normalize every capture on read. Set legacy captures globalState active. Resolve
legacy paths through Desktop identities: active marker gives workspaceId,
otherwise set workspaceState unavailable. Store global captures once; workspace
views filter the canonical collection by workspaceId rather than duplicate
storage keys. Reject permanent deletion without an explicit confirm token from
the UI.

- [ ] **Step 4: Run green and commit**

Run:

~~~bash
node scripts/smoke-browser-inbox-plugin.js
./scripts/check.sh
git -C /home/mirivlad/git/verstak2/verstak-official-plugins add plugins/browser-inbox scripts/smoke-browser-inbox-plugin.js
git -C /home/mirivlad/git/verstak2/verstak-official-plugins commit -m "feat: preserve archived browser inbox captures"
git -C /home/mirivlad/git/verstak2/verstak-desktop add internal/api/app.go internal/api/app_test.go
git -C /home/mirivlad/git/verstak2/verstak-desktop commit -m "feat: migrate browser inbox relations"
~~~

Expected: migration, archive, restore, and assignment tests pass.

### Task 2: Handle rename, Trash, restore, purge, and archive UI

**Files:**
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/plugins/browser-inbox/frontend/src/index.js
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/scripts/smoke-browser-inbox-plugin.js
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/e2e/browser-inbox.spec.js
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/src/lib/test/wails-mock.js

**Interfaces:**
- Receives workspace.renamed, workspace.trashed, workspace.restored, and workspace.purged.
- Status filter values are active, archive, all.
- Archive bulk action is restore; bulk permanent delete is not offered.

- [ ] **Step 1: Write failing lifecycle and UI tests**

Assert a rename changes only path cache, trash disables routing, restore restores
the same workspace ID, purge makes captures unassigned and bindings orphaned:

~~~js
await emitWorkspaceEvent('workspace.trashed', { workspaceId: 'w-1', trashId: 't-1' });
assert.equal(capture.workspaceState, 'trashed');
assert.equal(domainBinding('client.example').state, 'trashed');
await emitWorkspaceEvent('workspace.purged', { workspaceId: 'w-1', trashId: 't-1' });
assert.equal(capture.workspaceState, 'unassigned');
assert.equal(domainBinding('client.example').state, 'orphaned');
~~~

In Playwright, select Archive, restore one visible item, and bulk-restore only
the filtered archive rows. Also click Delete everywhere for an assigned capture,
assert the dialog names its assigned Дело, cancel, and assert that the global
and assigned rows still exist.

- [ ] **Step 2: Run red**

Run:

~~~bash
cd /home/mirivlad/git/verstak2/verstak-desktop/frontend
npm run test:e2e -- browser-inbox.spec.js
~~~

Expected: FAIL because the current UI has only processed filters and destructive Clear.

- [ ] **Step 3: Implement lifecycle and labels**

Subscribe once from the Browser Inbox background service. Update path caches on
rename only when workspaceId matches. On external unavailable, do not route to
the same path again. Add Active, Archive, and All filters; make search apply
inside the selected filter; show Archive badge inside a case; add Restore to
Inbox and visible filtered bulk restore. Rename Clear to an archive action with
count confirmation. Keep Delete everywhere separate and require a dialog that
names the assigned Дело; cancellation must perform no mutation.

- [ ] **Step 4: Run green and commit**

Run:

~~~bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins && node scripts/smoke-browser-inbox-plugin.js
cd /home/mirivlad/git/verstak2/verstak-desktop/frontend && npm run test:e2e -- browser-inbox.spec.js
git -C /home/mirivlad/git/verstak2/verstak-official-plugins add plugins/browser-inbox scripts/smoke-browser-inbox-plugin.js
git -C /home/mirivlad/git/verstak2/verstak-official-plugins commit -m "feat: add browser inbox archive lifecycle"
git -C /home/mirivlad/git/verstak2/verstak-desktop add frontend/e2e/browser-inbox.spec.js frontend/src/lib/test/wails-mock.js
git -C /home/mirivlad/git/verstak2/verstak-desktop commit -m "test: cover browser inbox archive lifecycle"
~~~

Expected: archive filters, restore, rename, Trash, restore, and purge tests pass.

### Task 3: Save and open durable links without file-association reliance

**Files:**
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/permissions/registry.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/api/app.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/api/app_test.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/src/lib/plugin-host/VerstakPluginAPI.js
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/plugins/browser-inbox/plugin.json
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/plugins/browser-inbox/frontend/src/index.js
- Modify: /home/mirivlad/git/verstak2/verstak-official-plugins/scripts/smoke-browser-inbox-plugin.js

**Interfaces:**
- Permission and API: urls.openExternal(url string) for user-initiated HTTP(S) URLs only.
- SaveLinkInCase(captureId, workspaceId, filename) creates Links/name.url with InternetShortcut URL field.
- Collision response offers a proposed unique filename and never overwrites.

- [ ] **Step 1: Write failing API and plugin tests**

Add tests for invalid URL, readonly failure, unique filename, collision, and
direct opener argument:

~~~go
if errStr := app.OpenExternalURL("browser.plugin", "https://example.test/a"); errStr != "" {
    t.Fatal(errStr)
}
if got := opener.Arguments[0]; got != "https://example.test/a" {
    t.Fatalf("opened %q, want URL not .url path", got)
}
~~~

Add plugin smoke assertions for a title-derived name, Link fallback, and
proposal Link (2).url after a collision.

- [ ] **Step 2: Run red**

Run:

~~~bash
cd /home/mirivlad/git/verstak2/verstak-desktop
GOCACHE=/tmp/verstak-go-cache go test ./internal/api -run 'Test.*OpenExternalURL' -count=1
cd /home/mirivlad/git/verstak2/verstak-official-plugins
node scripts/smoke-browser-inbox-plugin.js
~~~

Expected: FAIL because only file-path external opening exists.

- [ ] **Step 3: Implement safe save and open**

Register urls.openExternal as dangerous. Validate HTTP(S), invoke the existing
OS opener with the URL string, and expose api.urls.openExternal. Browser Inbox
requests that permission, creates Links through files.createFolder and
files.writeText using:

~~~text
[InternetShortcut]
URL=https://example.test/
~~~

Sanitize a 96-character filename stem. On collision show an editable dialog
with proposed name (2).url and Cancel; leave capture state unchanged on errors.
When opening a saved link, parse and validate URL= before invoking the URL API.

- [ ] **Step 4: Run green and commit**

Run:

~~~bash
cd /home/mirivlad/git/verstak2/verstak-desktop && GOCACHE=/tmp/verstak-go-cache go test ./internal/api -count=1
cd /home/mirivlad/git/verstak2/verstak-official-plugins && node scripts/smoke-browser-inbox-plugin.js
git -C /home/mirivlad/git/verstak2/verstak-desktop add internal/core/permissions internal/api frontend/src/lib/plugin-host
git -C /home/mirivlad/git/verstak2/verstak-desktop commit -m "feat: open external URLs safely"
git -C /home/mirivlad/git/verstak2/verstak-official-plugins add plugins/browser-inbox scripts/smoke-browser-inbox-plugin.js
git -C /home/mirivlad/git/verstak2/verstak-official-plugins commit -m "feat: save browser inbox links safely"
~~~

Expected: URL API tests and link save/collision smoke tests pass.

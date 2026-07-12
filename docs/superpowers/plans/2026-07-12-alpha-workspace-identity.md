# Alpha Workspace Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Give every managed Дело a durable UUID identity and publish lifecycle events that let alpha features follow a case across rename, Trash, restore, and path reuse.

**Architecture:** The filesystem remains the source of truth for whether a case folder exists. A UUID marker inside each case is the relation identity; Desktop metadata indexes that marker and paths remain presentation caches.

**Tech Stack:** Go, Wails bindings, JSON metadata, Go tests.

## Global Constraints

- A new Дело is created only by an explicit user action.
- workspaceId is UUID v4; a path is never relation identity.
- The marker is .verstak/workspace.json inside the case.
- Existing writable cases migrate without data loss; non-writable cases are view-only.
- Use TDD and make one commit per task.

---

### Task 1: Store and resolve durable workspace identities

**Files:**
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/workspace/manager.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/workspace/manager_test.go

**Interfaces:**
- Produces Workspace.ID string and Metadata.WorkspaceID string.
- Produces func (m *Manager) EnsureWorkspaceIdentity(name string) (WorkspaceIdentity, error).
- Produces func (m *Manager) ListWorkspaceIdentities() ([]WorkspaceIdentity, error).

- [ ] **Step 1: Write the failing identity tests**

Add tests proving creation writes a UUID marker, rename retains it, and a newly
created folder after external removal gets another UUID:

~~~go
ws, err := m.CreateWorkspace("Clients", "default")
if err != nil { t.Fatal(err) }
first, err := m.EnsureWorkspaceIdentity(ws.Name)
if err != nil || first.WorkspaceID == "" { t.Fatalf("identity = %+v, %v", first, err) }
if err := m.RenameWorkspace("Clients", "Clients-2026"); err != nil { t.Fatal(err) }
renamed, _ := m.EnsureWorkspaceIdentity("Clients-2026")
if renamed.WorkspaceID != first.WorkspaceID { t.Fatal("rename changed workspace ID") }
~~~

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

~~~bash
cd /home/mirivlad/git/verstak2/verstak-desktop
GOCACHE=/tmp/verstak-go-cache go test ./internal/core/workspace -run 'Test.*Workspace.*Identity' -count=1
~~~

Expected: FAIL because WorkspaceIdentity and EnsureWorkspaceIdentity do not exist.

- [ ] **Step 3: Write the minimal marker implementation**

Add these types and use them in CreateWorkspace, GetWorkspaceMetadata, and
workspace listing:

~~~go
type WorkspaceIdentity struct {
    WorkspaceID string `json:"workspaceId"`
    RootPath    string `json:"rootPath"`
    State       string `json:"state"`
}

const workspaceIdentityRelativePath = ".verstak/workspace.json"

func (m *Manager) EnsureWorkspaceIdentity(name string) (WorkspaceIdentity, error) {
    // Validate the folder, read the in-folder marker, and atomically create
    // a UUID-v4 marker only when absent and writable.
}
~~~

Write the same ID to central metadata only as an index. Never recover an ID from
stale path-keyed metadata when the in-folder marker is absent.

- [ ] **Step 4: Run green and commit**

Run:

~~~bash
GOCACHE=/tmp/verstak-go-cache go test ./internal/core/workspace -count=1
git add internal/core/workspace/manager.go internal/core/workspace/manager_test.go
git commit -m "feat: add durable workspace identities"
~~~

Expected: tests pass and the commit contains only workspace identity changes.

### Task 2: Expose identity and lifecycle events through Desktop

**Files:**
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/api/app.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/api/app_test.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/src/App.svelte
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/wailsjs/go/api/App.d.ts
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/frontend/wailsjs/go/models.ts

**Interfaces:**
- Produces ListWorkspaceIdentities() ([]workspace.WorkspaceIdentity, string).
- Lifecycle payloads include workspaceId and workspaceRootPath; Trash also includes trashId.
- Produces workspace.restored and workspace.purged events.

- [ ] **Step 1: Add failing API tests**

Extend TestWorkspaceAPIPublishesLifecycleEvents:

~~~go
if got := received["workspace.created"]["workspaceId"]; got == "" {
    t.Fatal("workspace.created must include workspaceId")
}
if got := received["workspace.renamed"]["workspaceId"]; got != createdID {
    t.Fatalf("rename ID = %v, want %s", got, createdID)
}
~~~

Add restore and purge tests around RestoreVaultTrash and DeleteVaultTrash that
assert the original UUID and trash ID are emitted.

- [ ] **Step 2: Run red**

Run:

~~~bash
GOCACHE=/tmp/verstak-go-cache go test ./internal/api -run 'TestWorkspaceAPI.*Lifecycle' -count=1
~~~

Expected: FAIL because lifecycle payloads only identify a path.

- [ ] **Step 3: Publish complete identity lifecycle**

Resolve the marker before publishing create, rename, selected, and trashed
events. Detect workspace Trash metadata in RestoreVaultTrash and
DeleteVaultTrash, then publish:

~~~go
map[string]interface{}{
    "operation": "restore",
    "workspaceId": identity.WorkspaceID,
    "workspaceRootPath": restoredRoot,
    "trashId": trashID,
}
~~~

Change App.svelte workspace-node conversion to preserve workspace.id while using
rootPath only for selection and display.

- [ ] **Step 4: Run green and commit**

Run:

~~~bash
GOCACHE=/tmp/verstak-go-cache go test ./internal/api ./internal/core/workspace -count=1
git add internal/api/app.go internal/api/app_test.go frontend/src/App.svelte frontend/wailsjs/go/api/App.d.ts frontend/wailsjs/go/models.ts
git commit -m "feat: publish workspace identity lifecycle"
~~~

Expected: focused API and workspace tests pass.

### Task 3: Migrate legacy references and repair duplicate IDs

**Files:**
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/workspace/manager.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/workspace/manager_test.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/api/app.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/api/app_test.go

**Interfaces:**
- Produces RepairWorkspaceIdentity(keepRootPath, regenerateRootPath string) string.
- Identity states are active, unavailable, or duplicate.
- Later Inbox and Activity plans consume workspaceId through ListWorkspaceIdentities.

- [ ] **Step 1: Write failing duplicate and legacy tests**

Create two folders with copied marker data and assert neither is an active
relation target. Create a legacy path-keyed capture fixture and assert a
resolved path gets an ID while a missing path becomes unavailable:

~~~go
if errStr := app.RepairWorkspaceIdentity("Original", "Copied"); errStr != "" {
    t.Fatal(errStr)
}
if originalID == copiedID { t.Fatal("repair must issue a new ID") }
~~~

- [ ] **Step 2: Run red**

Run:

~~~bash
GOCACHE=/tmp/verstak-go-cache go test ./internal/core/workspace ./internal/api -run 'Test.*(Duplicate|Legacy).*Workspace' -count=1
~~~

Expected: FAIL because copied markers are accepted as ordinary folders.

- [ ] **Step 3: Implement deterministic repair**

Group active roots by marker UUID during identity listing. Mark a group with
more than one root duplicate and exclude it from assignment targets.
RepairWorkspaceIdentity verifies the duplicate, keeps the first marker, creates
a new marker for the second root, and moves no relation data.

- [ ] **Step 4: Run green and commit**

Run:

~~~bash
GOCACHE=/tmp/verstak-go-cache go test ./internal/core/workspace ./internal/api -count=1
git add internal/core/workspace/manager.go internal/core/workspace/manager_test.go internal/api/app.go internal/api/app_test.go
git commit -m "feat: repair duplicate workspace identities"
~~~

Expected: legacy, path-reuse, and duplicate-ID tests pass.

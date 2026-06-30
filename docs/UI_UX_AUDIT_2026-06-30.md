# Verstak2 UI/UX Audit - 2026-06-30

## Scope

This audit compares current Verstak2 against the old Verstak repository at
`/home/mirivlad/git/verstak`. The old repository is used only as UI/UX,
feature, and workflow reference. Code and architecture are not copied.

No previous complete UI/UX comparison report was found in the Verstak2
repositories. Existing documents cover implementation plans and roadmap items,
but not an end-to-end scenario audit.

## Environment

- Date: 2026-06-30
- Verstak2 desktop repo: `/home/mirivlad/git/verstak2/verstak-desktop`
- Old Verstak repo: `/home/mirivlad/git/verstak`
- Tooling:
  - Node.js v24.18.0 installed locally under `/tmp/verstak2-tools`
  - Playwright Chromium used through local CLI wrapper
  - Wails CLI v2.12.0 installed locally
  - Debian 13 WebKitGTK package present as `libwebkit2gtk-4.1-dev`
- Wails note:
  - `wails doctor` still reports missing `libwebkit2gtk-4.0-dev`.
  - Wails v2.12.0 supports WebKitGTK 4.1 with Go build tag `webkit2_41`.
  - `go test -tags webkit2_41 ./...` passes for current `verstak-desktop`.

## Artifacts

Screenshots are stored in:

`docs/ui-ux-audit-assets/2026-06-30/`

- `v1-start.png`
- `v1-today.png`
- `v1-inbox.png`
- `v1-activity.png`
- `v2-plugin-manager.png`
- `v2-workspace-files.png`
- `v2-command-palette.png`
- `v2-workspace-activity.png`
- `v2-workspace-browser-inbox.png`

## Verification Summary

### Repository Update

All Verstak2 subrepositories were updated. `verstak-desktop` initially could
not fast-forward because of local tracked changes in generated Wails typings
and `scripts/build.sh`. Those changes were saved in:

`stash@{0}: codex-pre-ui-audit-desktop-update`

After that, `verstak-desktop` fast-forwarded to `origin/main`.

### Automated Checks

Current `verstak-desktop`:

- `go test -tags webkit2_41 ./...`: pass
- `npm --prefix frontend run build`: pass
- `frontend npm run test:e2e`: 42 passed, 11 failed
- `scripts/check.sh` with `GOFLAGS=-tags=webkit2_41`: fails on gofmt only:
  - `plugins/platform-test/backend/main.go`
  - `build/bin/plugins/platform-test/backend/main.go`

### E2E Failures Worth Tracking

The failed E2E tests cluster around:

- Plugin Manager navigation selectors expecting `.sidebar .nav-item` while the
  current sidebar uses different structure/classes.
- File/workbench editor height regressions:
  - text editor height was about 266px where test expects over 300px;
  - markdown preview height was about 217px where test expects over 300px.
- Platform Test status bar component failure:
  - `openDiagnostics` component not found in bundle.
- Sync status bar failure:
  - `SyncStatusBar` bundle content is empty.

Some selector failures may be stale test assumptions. The editor height and
status bar errors are visible workflow/UI issues.

### Post-Pull Status - 2026-06-30 Later Sync

After pulling `verstak-desktop` to `46f754c` (`feat: workspace routing,
GlobalSearch, and shell refinements`), several roadmap items from this audit
are now implemented and verified.

Current verification:

- `GOFLAGS=-tags=webkit2_41 go test ./...`: pass
- `npm --prefix frontend run test:e2e`: 71 passed
- Focused UX coverage now includes:
  - app starts in the first workspace instead of Plugin Manager;
  - workspace opens with a shell-level Today tab before plugin tools;
  - workspace selection and main content stay in sync after Plugin Manager
    round trips;
  - workspace tool selection survives Workbench open/back/close flows;
  - status bar plugin failures do not render large error panels;
  - Plugin Manager remains reachable from the status/settings menu;
  - Files uses readable dates and understandable labeled controls;
  - Vault Selection is localized and has clear primary actions;
  - global search stays visible after opening tool views;
  - global search searches workspaces and file contents with RU/EN layout
    fallback;
  - plugin settings modal has enough space for complex panels;
  - Browser Inbox desktop workflow renders an empty capture flow, stored
    captures, detail metadata, and create/remove actions;
  - Activity desktop workflow renders an empty event flow, stored events, and
    worklog suggestions;
  - Command Palette promotes shell workflow commands before diagnostics and can
    open Today, Files, Activity, Browser Inbox, Plugin Manager, and start
    markdown/text file creation;
  - Command Palette can run Sync Now and open Sync settings.

The historical screenshots in `docs/ui-ux-audit-assets/2026-06-30/` remain
useful as "before" evidence, but the active roadmap below supersedes the
original P0 ordering.

## Scenario Findings

### 1. First Meaningful Screen

Old Verstak opens into a working shell:

- left navigation has clear system sections: Today, Inbox, Activity;
- workspace tree sits in the same navigation context;
- global search is immediately visible in the header;
- sync status and settings are discoverable but secondary.

Verstak2 opens into Plugin Manager:

- the first screen is technical/admin-oriented rather than user-task-oriented;
- plugin cards expose implementation details such as capabilities, roots,
  permissions, API versions, and contribution counts;
- status bar plugin errors are visible immediately;
- workspace entry exists in the sidebar, but it is not the primary landing
  experience.

Verdict: Verstak2 is feature-visible, but not user-workflow-first.

### 2. Navigation Model

Old Verstak has one coherent navigation model:

- System section for cross-workspace workflows;
- Workspace section for user cases/spaces;
- settings and sync anchored at the bottom;
- current page title and search are consistent.

Verstak2 separates:

- Tools;
- Workspaces;
- workspace tabs;
- Plugin Manager;
- status bar settings.

This is architecturally accurate for a platform, but it leaks platform concepts
too strongly into daily use. The user needs "work", "capture", "search",
"activity", and "settings"; they should not need to reason about plugin
contributions on the main path.

### 3. Workspace Files

Verstak2 workspace Files is one of the stronger current screens:

- workspace header exists;
- search slot exists;
- Files, Activity, Browser Inbox tabs are correctly scoped to workspace;
- file rows, folder rows, filtering, sorting, and action buttons are present.

Problems:

- Files toolbar buttons render visually as near-identical small squares in the
  screenshot. Accessibility names exist, but visible affordance is poor.
- Editor/preview area appears too short in E2E, causing regressions for file
  opening workflows.
- Status bar error area consumes a large part of the lower viewport and reduces
  usable file space.

### 4. Activity

Old Verstak gives Activity a clear system-level place and empty state.
Today also exposes related workflow tabs: feed, suggestions, in-progress,
captures, browser.

Original Verstak2 desktop mock rendered only:

- heading `Activity`;
- text `Global activity feed`.

Current desktop shell/mock now mirrors the official Activity plugin's core
visible workflow: scoped empty state, event count, stored event rows, clear
action, and worklog suggestions. Remaining work is to expose real activity
ingestion and Journal import from the visible app flow, not just prove the
surface contract in mock E2E.

### 5. Browser Inbox / Capture Flow

Old Verstak "Неразобранное" has:

- a clear name for unprocessed captures;
- explanatory text;
- an immediate visible action: paste from clipboard.

Original Verstak2 desktop mock rendered only:

- heading `Browser Inbox`;
- text `Global browser inbox`.

Current desktop shell/mock now mirrors the official Browser Inbox plugin's core
visible workflow: scoped empty state, capture count, stored capture rows,
detail metadata, and visible conversion/remove actions. Remaining work is to
make the real capture ingestion path and extension pairing visible from the
app.

### 6. Command Palette

Verstak2 command palette opens and is keyboard-accessible. Current visible
commands are only Platform Test commands. It is useful infrastructure, but not
yet a meaningful user launcher.

Expected near-term commands:

- open/create workspace;
- search workspace;
- create note;
- create file;
- open Browser Inbox;
- open Activity;
- sync now / sync settings;
- plugin/settings only after user tasks.

### 7. Status Bar

Status bar is currently the largest immediate UX blocker.

Observed:

- permanent lower panel shows plugin errors;
- error cards overlap/consume workspace area;
- messages expose internal plugin/component/bundle details;
- normal user status is visually dominated by red plugin failure content.

The old version keeps sync/settings status quiet and secondary. Verstak2 should
follow that principle: status should be compact, actionable, and non-blocking.
Developer diagnostics belong behind an explicit diagnostics surface.

## Priority Plan

### DONE - Remove User-Facing Internal Errors From Main Workspace

Goal: no normal user screen should be dominated by plugin bundle errors.

Status: implemented in `verstak-desktop` and verified by
`frontend/e2e/ux-p0.spec.js` plus `frontend/e2e/status-bar.spec.js`.

Actions:

- Fix Platform Test status contribution:
  - manifest/component mismatch around `openDiagnostics` vs available bundle
    components.
- Fix Sync status contribution:
  - empty frontend bundle content for `SyncStatusBar`.
- Change status bar error rendering:
  - compact "Plugin issue" badge;
  - details only on click;
  - cap height so it cannot cover workspace content.

Verification:

- `frontend/e2e/status-bar.spec.js` passes.
- First workspace screenshot has no large red error cards.

### DONE - Make Workspace The Default User Landing

Goal: after vault opens, user lands in a productive workspace or Today-style
overview, not Plugin Manager.

Status: implemented in `verstak-desktop`; current mock flow starts in the first
workspace and keeps Plugin Manager reachable through settings.

Actions:

- If a vault has workspaces, open the last active workspace.
- If no workspace exists, show a first-run workspace creation screen.
- Move Plugin Manager out of the primary default route:
  - keep accessible through Settings;
  - optionally expose via command palette.

Verification:

- Initial app screen shows workspace or useful overview.
- Plugin Manager remains reachable but is not the first user-facing surface.

### PARTIAL - Restore Old "Today / Inbox / Activity" Workflow Shape

Goal: preserve the old product's user workflow while keeping Verstak2 plugin
architecture.

Status: first shell-level Today surface is implemented in `verstak-desktop`.
Workspace now opens with `Today` before plugin tools, showing captures, recent
activity, worklog suggestions, and quick actions. The Today "Open Inbox" action
switches into the workspace Browser Inbox tool, and Files remains stable after
Workbench open/back/close flows.

Remaining gap: this is still a thin aggregation layer. Activity, Browser Inbox,
and Journal exist as plugin-backed surfaces, but the old product's richer
"what should I do now?" flow needs real capture/activity/journal data density
and stronger empty-state actions. Current architecture has the ingredients:

- `verstak.activity` stores scoped activity and exposes worklog suggestion
  command `verstak.activity.suggestWorklog`;
- `verstak.browser-inbox` stores scoped captures and can convert captures into
  notes, links, and files;
- `verstak.journal` stores worklog entries and can import Activity suggestions;
- `GlobalSearch` indexes workspaces, tools, files, Browser Inbox, Activity, and
  Journal plugin settings.

Actions:

- Expand the user-level `Today` surface with richer real data.
- Surface and prioritize:
  - recent activity;
  - unprocessed captures;
  - in-progress work;
  - worklog suggestions;
  - quick create actions.
- Keep implementation plugin-driven, but present as one coherent workflow.
- Add first-class commands for opening Today, Inbox, Activity, and creating
  work items.

Verification:

- User can answer "what should I do now?" from the first screen.
- Browser captures and activity are visible without opening Plugin Manager.
- `frontend/e2e/ux-today.spec.js` covers Today-first startup and the Today to
  Browser Inbox quick-action path.

### PARTIAL - Make Activity A Real Visible Workflow

Goal: Activity should look useful even with no events and should connect events
to worklog reconstruction.

Status: partially implemented. The real Activity plugin has scoped storage,
event subscriptions, worklog suggestion generation, and a command contribution
for `verstak.activity.suggestWorklog`. The desktop E2E/mock surface now mirrors
the core visible workflow: scoped empty state, event count, stored event rows,
clear action, and worklog suggestions.

Remaining UX work is mostly around real activity ingestion from app actions,
Journal import/review, and making suggestions actionable from Today/Activity
rather than merely visible.

Actions:

- Keep empty-state copy explaining that file changes, browser captures, and
  conversions will appear here.
- Add visible actions for:
  - import worklog suggestion to Journal;
  - filter by source/type;
  - open related file/capture from an activity row.
- Connect Today worklog suggestions to Activity/Journal actions.

Verification:

- Empty Activity explains what will appear.
- Stored events render with source/type/summary.
- Worklog suggestions are visible from activity events.
- `frontend/e2e/activity.spec.js` covers the desktop shell/mock contract.

### PARTIAL - Make Browser Inbox A Real Visible Workflow

Goal: Browser Inbox should look usable even when empty.

Status: partially implemented. The real Browser Inbox plugin has storage,
event subscriptions, scoped capture lists, domain binding, and Create Note /
Create Link / Create File actions for selected captures. The desktop E2E/mock
surface now mirrors the core visible workflow: scoped empty state, capture
count, stored capture list, detail metadata, and Create Note / Create Link /
Create File / Remove actions. Today also opens this workspace tool directly.

Remaining UX work is mostly around actual primary capture actions, extension
pairing/settings visibility, and making the real capture ingestion path easy to
exercise from the app.

Actions:

- Keep empty-state copy explaining capture flow.
- Add primary actions:
  - paste from clipboard;
  - open browser extension pairing/settings;
  - create note/link/file from selected capture when data exists.
- Show domain/workspace binding state if configured.

Verification:

- Empty Browser Inbox explains the capture flow.
- Stored captures render with visible metadata and conversion actions.
- Captures can be converted from the visible UI in the real plugin.
- `frontend/e2e/browser-inbox.spec.js` covers the desktop shell/mock contract.

### DONE - Fix Files Toolbar Visual Affordance

Goal: toolbar buttons must be visually recognizable, not identical dark boxes.

Status: implemented and verified by `frontend/e2e/ux-p0.spec.js` and the full
Files E2E suite. Files now uses readable dates and understandable action
controls; editor/preview height regressions are covered by passing E2E.

Actions:

- Ensure Lucide icons render with sufficient contrast and size.
- Add tooltips for icon-only buttons.
- Disable unavailable actions visibly instead of showing identical active
  squares.
- Keep layout dense, but make grouping clear: navigation, create, selected item
  actions, clipboard, filter/sort.

Verification:

- Screenshot shows recognizable icons.
- Buttons have accessible names and hover tooltips.
- File open editor/preview height returns above E2E threshold.

### PARTIAL - Make Command Palette User-Oriented

Goal: command palette should be a power-user entry point for real tasks.

Status: partial. Command Palette works, executes active plugin commands, and
now promotes shell workflow commands above diagnostics: Open Today, Open Files,
Open Activity, Open Browser Inbox, Open Plugin Manager, Create Markdown File,
Create Text File, Sync Now, and Open Sync Settings. Remaining command coverage
gaps are capture actions, richer note templates, Journal import/review, and
hiding test diagnostics from production-like mode.

Actions:

- Register remaining user commands from Browser Inbox, Activity, Search, and
  Journal.
- Keep user commands ranked above diagnostics/test commands.
- Hide test/plugin diagnostics from production-like mode.

Verification:

- `Ctrl+K` shows open Today/Files/Activity/Inbox commands before diagnostics.
- `Ctrl+K` can start markdown/text file creation through the visible Files
  workflow.
- `Ctrl+K` can run Sync Now and open Sync settings.
- `frontend/e2e/command-palette.spec.js` covers shell command ranking and the
  Open Activity, create-file, and sync command paths.

### DONE - Reduce Plugin Manager Density

Goal: Plugin Manager should remain useful but stop looking like the product's
main screen.

Status: implemented enough for the current roadmap. Plugin cards now show a
short default surface and hide API version, root, capabilities, optional
requires, and permissions under `Technical details`.

Actions:

- Split default view into simple plugin list:
  - name;
  - enabled/disabled;
  - short description;
  - settings;
  - disable/enable.
- Put capabilities, permissions, roots, and contribution details behind
  expandable "Developer details".

Verification:

- Plugin Manager fits more plugins per viewport.
- Non-developer user can safely enable/disable/configure without reading
  internal contracts.

## Next Review Steps

1. Design and implement the next Today follow-up: make captures, Activity
   worklog suggestions, and Journal import/review actionable from the first
   workspace screen.
2. Re-run:
   - `GOFLAGS=-tags=webkit2_41 ./scripts/check.sh`
   - `npm --prefix frontend run test:e2e`
3. Re-capture the same screenshots as "after" evidence.
4. Run real Wails GUI smoke with:
   - `wails dev -tags webkit2_41`
5. Do a second audit focused on:
   - first-run/open vault;
   - real filesystem vault;
   - Browser extension capture;
   - native window/WebKitGTK rendering differences.

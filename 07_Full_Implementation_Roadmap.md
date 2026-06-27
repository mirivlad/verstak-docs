# Verstak2 Full Implementation Roadmap

## 1. Goal

Bring Verstak2 to a complete standalone local-first desktop product:

- core platform and UI shell can run without official plugins;
- official plugins provide the user-facing tools;
- vault data stays human-readable and local-first;
- sync, browser capture, activity, journal, preview, search, and secrets are
  plugin/runtime extensions, not mandatory core modules;
- no compatibility bridge to the first Verstak version is introduced.

## 2. Non-negotiable Constraints

- No v1 migration bridge or temporary compatibility layer.
- No notes/files/editor/activity/journal/browser inbox feature may become a
  required core module.
- User documents remain ordinary vault files unless a feature explicitly needs
  protected storage, such as secrets.
- `Overview.md` is an ordinary Markdown filename, not a special UI entity.
- New plugin-facing behavior must go through public Verstak2 API contracts and
  SDK/schema updates.
- Every significant step must be verified, committed, and pushed separately.

## 3. Current Baseline

Implemented:

- plugin discovery, manifest validation, lifecycle states, enable/disable;
- capability, permission, contribution, event, settings, storage foundations;
- bundled frontend plugin host and `VerstakPluginAPI`;
- Command Palette UI host for `commands` contributions;
- Status Bar UI host for `statusBarItems` contributions;
- workspace top-level folder model and workspace item host;
- Files Core text API with safe path policy and sync operation recording;
- public `files.openExternal` / `files.showInFolder` API and Files plugin usage;
- Workbench open/edit provider routing and default editor plugin;
- official Files plugin, Notes plugin, Sync plugin, and platform-test plugin;
- sync server with device/user auth and operation push/pull;
- SDK manifest/types/schema coverage for current plugin APIs;
- automated Go, frontend, official plugin, SDK, and real-sync smoke checks.

Known remaining gaps:

- `fileActions`, `noteActions`, `contextMenuEntries`, `searchProviders`,
  `activityProviders` have registry support but incomplete UI/runtime hosting.
- Sidecar host is not implemented.
- Files/Notes are usable but not complete: restore, binary streaming, watcher,
  richer conflict UX, and Notes trash/delete UX are still incomplete.
- Markdown/file preview, activity, journal, browser inbox receiver/plugin, search, secrets, and
  templates plugins are not complete product features.
- Browser extension repository has protocol, queue, and Chromium/Firefox build
  scaffold, but no paired desktop local receiver yet.
- Packaging/update/release workflow is not product-grade yet.

## 4. Implementation Phases

### Phase 1 - Platform Runtime Completion

Goal: finish generic host surfaces that plugins need before adding more product
plugins.

Tasks:

- [x] implement Command Palette UI for `commands` contributions;
- [x] host `statusBarItems`;
- define and host generic `contextMenuEntries`;
- host `fileActions` and `noteActions` through Files/Notes surfaces;
- add lifecycle events for workspace creation, rename, trash, selection;
- replace deprecated workspace compatibility wrappers in frontend code where
  practical;
- document each public API in SDK schemas and desktop runtime docs.

Verification:

- focused e2e tests for command palette, status bar, and contribution lifecycle;
- `go test ./...`, frontend build/e2e, official plugin checks, SDK tests.

### Phase 2 - Files And Notes Product Surface

Goal: make Files and Notes feel like complete daily-use tools while keeping
storage as ordinary Markdown/files.

Tasks:

- improve Notes list filtering, sorting, rename/conflict UX, and empty states;
- [x] add Notes delete/trash through Files API with confirmation;
- add Files restore metadata view and later restore command;
- [x] define external open/show-in-folder as a public v2 API, replacing fallback;
- add watcher-based refresh for Files/Notes after external changes;
- add safe binary read/streaming contract only after text workflows are stable.

Verification:

- plugin smoke tests and desktop e2e for create/open/rename/trash/reload;
- no `.verstak/notes`, no special `Overview.md`, no direct backend bypasses.

### Phase 3 - Sync Hardening

Goal: make cross-device sync reliable enough for real vaults.

Tasks:

- define conflict UX contract for desktop and sync plugin;
- [x] add server/device revocation checks for sync auth paths;
- persist and display sync errors in Sync plugin;
- add retry/backoff for sync client operations;
- [x] add real two-vault sync smoke scenarios for create/update/move/trash
  folders and files;
- document deployment and backup procedures for `verstak-sync-server`.

Verification:

- sync server `go test ./...`;
- desktop real sync smoke;
- official Sync plugin settings/status tests.

### Phase 4 - Preview, Search, Activity, Journal

Goal: add the next visible product layer as replaceable plugins.

Tasks:

- implement `verstak.markdown-preview` provider plugin;
- implement basic file/image preview plugin;
- implement search provider/index contract and official search plugin;
- implement activity event log plugin;
- implement journal/worklog plugin that can consume activity suggestions.

Verification:

- provider selection tests;
- plugin lifecycle tests proving optional dependencies degrade cleanly.

### Phase 5 - Browser Inbox

Goal: capture browser context into the local vault through a public local
receiver and an official inbox plugin.

Tasks:

- [x] define browser capture payload protocol;
- implement `verstak.browser-inbox` plugin with pending queue;
- [x] implement browser extension capture scaffold for URL, selected text,
  page title, and link captures;
- define local receiver permission/pairing model;
- add domain-to-workspace binding;
- convert inbox entries into notes/links/files/activity events through public
  plugin APIs.

Verification:

- extension build checks;
- local receiver API tests;
- inbox plugin smoke/e2e tests.

### Phase 6 - Secrets

Goal: provide protected storage for credentials without turning secrets into
notes or plain files.

Tasks:

- define secret-store capability and permissions;
- implement encrypted local secret storage;
- add UI-only official secrets plugin;
- integrate secret references with workspaces without exposing raw values to
  unrelated plugins.

Verification:

- permission denial tests;
- storage encryption and no-plaintext regression checks.

### Phase 7 - Sidecar/Sandbox Boundary

Goal: move from trusted bundled plugin JavaScript toward safer plugin execution.

Tasks:

- implement sidecar launch protocol and local RPC;
- permission-scope sidecar APIs;
- stop sidecars on plugin disable;
- surface sidecar logs and health in Plugin Manager;
- document supported sidecar languages and packaging rules.

Verification:

- sidecar health and permission tests;
- disable/failure lifecycle tests.

### Phase 8 - Packaging, Update, Release

Goal: produce installable, recoverable releases.

Tasks:

- define release artifact matrix for desktop, official plugins, SDK, sync server,
  and browser extension;
- add plugin package signing/verification or equivalent integrity checks;
- add backup/restore docs for vault and sync server;
- add crash/log collection for local diagnostics;
- build release smoke checklist.

Verification:

- clean build from clone;
- packaged desktop starts with bundled official plugins;
- documented recovery path works on a sample vault.

## 5. Immediate Execution Order

1. [x] Command Palette UI host in `verstak-desktop`.
2. [x] Status bar item host in `verstak-desktop`.
3. [x] External open public v2 API to replace Files fallback.
4. [x] Notes trash/delete UX in `verstak-official-plugins`.
5. [x] Sync hardening pass with expanded real two-vault smoke.
6. [~] Browser inbox protocol design and extension scaffold; receiver/plugin
   implementation still requires local receiver host work.

This order finishes generic platform surfaces before building product features
that depend on them.

## 6. Stop Conditions

Work can continue autonomously until one of these occurs:

- a decision requires product policy not present in docs;
- implementation needs credentials, signing keys, or external infrastructure;
- a repeated blocker appears after three evidence-based attempts;
- a repository has user changes that directly conflict with the next edit.

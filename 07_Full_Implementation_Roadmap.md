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
- Status Bar UI host for `statusBarItems`, vault status, and settings menu;
- workspace top-level folder model and workspace item host;
- Files Core text API with safe path policy and sync operation recording;
- public `files.openExternal` / `files.showInFolder` API and Files plugin usage;
- mode-aware Workbench open/edit provider routing and default editor plugin;
- official Files plugin, Notes plugin, Markdown Editor plugin, Search plugin,
  Sync plugin, and platform-test plugin;
- browser inbox local receiver and minimal official Browser Inbox plugin;
- sync server with device/user auth and operation push/pull;
- SDK manifest/types/schema coverage for current plugin APIs;
- automated Go, frontend, official plugin, SDK, and real-sync smoke checks.

Known remaining gaps:

- `fileActions`, `noteActions`, and `contextMenuEntries` are exposed through the
  desktop contribution summary and hosted by the official Files/Notes surfaces.
- Sidecar host is not implemented.
- Files/Notes are usable but not complete: binary write/streaming, richer
  conflict UX, and remaining Notes polish are still incomplete.
- Activity, journal, browser inbox conversion workflow, indexed search,
  secrets, and templates plugins are not complete product features.
- File/image preview exists as a basic provider with bounded inline image
  rendering through the public Files API.
- Browser extension repository has protocol, queue, and Chromium/Firefox build
  scaffold; desktop has a local receiver and mounted-view inbox plugin, but no
  pairing model, domain binding, or conversion workflow yet.
- Packaging/update/release workflow is not product-grade yet.

## 4. Implementation Phases

### Phase 1 - Platform Runtime Completion

Goal: finish generic host surfaces that plugins need before adding more product
plugins.

Tasks:

- [x] implement Command Palette UI for `commands` contributions;
- [x] host `statusBarItems`;
- [x] define and host generic `contextMenuEntries`;
- [x] host `fileActions` and `noteActions` through Files/Notes surfaces;
- [x] add lifecycle events for workspace creation, rename, trash, selection;
- [x] replace deprecated workspace compatibility wrappers in frontend code where
  practical;
- [x] document each public API in SDK schemas and desktop runtime docs.

Verification:

- focused e2e/smoke tests for command palette, status bar, action surfaces, and
  contribution lifecycle;
- `go test ./...`, frontend build/e2e, official plugin checks, SDK tests.

### Phase 2 - Files And Notes Product Surface

Goal: make Files and Notes feel like complete daily-use tools while keeping
storage as ordinary Markdown/files.

Tasks:

- [x] improve Notes list filtering, sorting, and filtered empty states;
- [x] improve Notes rename/conflict UX;
- [x] add Notes delete/trash through Files API with confirmation;
- [x] add Files restore metadata view;
- [x] add Files restore command;
- [x] define external open/show-in-folder as a public v2 API, replacing fallback;
- [x] add watcher-based refresh for Files/Notes after external changes;
- [x] add safe binary read/streaming contract only after text workflows are stable.

Verification:

- plugin smoke tests and desktop e2e for create/open/rename/trash/reload;
- no `.verstak/notes`, no special `Overview.md`, no direct backend bypasses.

### Phase 3 - Sync Hardening

Goal: make cross-device sync reliable enough for real vaults.

Tasks:

- [x] define conflict UX contract for desktop and sync plugin;
- [x] add server/device revocation checks for sync auth paths;
- [x] persist and display sync errors in Sync plugin;
- [x] add retry/backoff for sync client operations;
- [x] add real two-vault sync smoke scenarios for create/update/move/trash
  folders and files;
- [x] document deployment and backup procedures for `verstak-sync-server`.

Verification:

- sync server `go test ./...`;
- desktop real sync smoke;
- official Sync plugin settings/status tests.

### Phase 4 - Preview, Search, Activity, Journal

Goal: add the next visible product layer as replaceable plugins.

Tasks:

- [x] keep Markdown preview inside `verstak.markdown-editor`, with no separate
  provider competing for `.md` files;
- [x] implement basic image metadata preview plugin;
- [x] implement baseline `verstak.search` workspace plugin and expose
  `searchProviders` in contribution summaries;
- [x] add type-as-you-search behavior and vault path/name matches to
  `verstak.search`;
- [x] implement baseline `verstak.activity` event log plugin with
  workspace-scoped storage, global aggregation, and public event subscriptions;
- [x] expose `verstak.activity` and `verstak.browser-inbox` as global sidebar
  views while keeping their workspace items;
- [x] implement persistent search index and cross-provider runtime hosting;
- [x] implement activity reconstruction and worklog suggestions;
- [x] implement journal/worklog plugin that can consume activity suggestions.

Verification:

- provider selection tests;
- plugin lifecycle tests proving optional dependencies degrade cleanly.

### Phase 5 - Browser Inbox

Goal: capture browser context into the local vault through a public local
receiver and an official inbox plugin.

Tasks:

- [x] define browser capture payload protocol;
- [x] implement minimal `verstak.browser-inbox` plugin with workspace-scoped
  pending queues and a global aggregate view;
- [x] implement browser extension capture scaffold for URL, selected text,
  page title, and link captures;
- [x] define local receiver permission/pairing model;
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
6. [~] Browser inbox protocol design, extension scaffold, local receiver, and
   minimal inbox plugin are implemented; pairing, domain binding, and conversion
   workflows remain.

This order finishes generic platform surfaces before building product features
that depend on them.

## 6. Stop Conditions

Work can continue autonomously until one of these occurs:

- a decision requires product policy not present in docs;
- implementation needs credentials, signing keys, or external infrastructure;
- a repeated blocker appears after three evidence-based attempts;
- a repository has user changes that directly conflict with the next edit.

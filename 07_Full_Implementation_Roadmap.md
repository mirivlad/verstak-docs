# Verstak Implementation Roadmap

## 1. Goal

Bring Verstak to a complete standalone local-first desktop product:

- core platform and UI shell can run without official plugins;
- official plugins provide the user-facing tools;
- vault data stays human-readable and local-first;
- sync UI/settings, browser capture, activity, journal, preview, search, and
  secrets are plugin/runtime extensions; sync correctness (scanner, operation
  log, reconciliation, and workspace identity) stays in Desktop core.

## 2. Non-negotiable Constraints

- No notes/files/editor/activity/journal/browser inbox feature may become a
  required core module.
- User documents remain ordinary vault files unless a feature explicitly needs
  protected storage, such as secrets.
- `Overview.md` is an ordinary Markdown filename, not a special UI entity.
- New plugin-facing behavior must go through public API contracts and
  SDK/schema updates.
- Every significant step must be verified, committed, and pushed separately.

## 3. Current Baseline

Implemented:

- plugin discovery, manifest validation, lifecycle states, enable/disable;
- capability, permission, contribution, event, settings, storage foundations;
- bundled frontend plugin host and `VerstakPluginAPI`;
- Command Palette UI host for `commands` contributions;
- Status Bar UI host for `statusBarItems`, vault status, and settings menu;
- workspace top-level folder model, workspace item host, workspace templates;
- Files Core API with safe path policy, durable snapshot scanning, atomic
  text/binary writes, and core sync operation recording;
- public `files.openExternal` / `files.showInFolder` API;
- mode-aware Workbench open/edit provider routing and default editor plugin;
- all official plugins: Files, Notes, Default Editor, File Preview, Activity,
  Journal, Browser Inbox, Search, Secrets, Todo, Trash, Sync, Templates;
- browser inbox local receiver with paired mode, domain bindings, and
  create-note/link/file conversion;
- sync server with device/user auth, operation push/pull, Blob transport,
  embedded web console, and real two-vault smoke scenarios;
- SDK manifest/types/schema coverage for plugin APIs;
- persisted System/English/Russian application language selection, localized
  desktop shell, public `api.i18n` plugin contract, and bilingual catalogs for
  all official plugins;
- automated Go, frontend, official plugin, SDK, and real-sync smoke checks;
- tray icon with native menu and native desktop notifications;
- AES-GCM secret store with master password, UI plugin.

Known remaining gaps:

- Sidecar host is not implemented (bundled plugins run in shared JS context).
- Chunked streaming/large-file import is deferred; bounded text (2 MB) and
  byte (8 MB) APIs are the current limits.
- UX polish is ongoing: Today flow as work-resume surface, Activity-to-Journal
  review, mobile/responsive layout, search in workspace header.
- Production-grade packaging, auto-update, and release workflow is partial:
  build scripts exist, but not a polished update channel.
- Sync operation-log retention/compaction is intentionally deferred.
- Secrets, plugin settings, Todo, Journal, Activity, and Browser Inbox are not
  synchronized yet.
- Browser extension chunked large-file capture is future work.
- Automatic conflict resolution is intentionally absent.

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

Status: done.

### Phase 2 - Files And Notes Product Surface

Goal: make Files and Notes feel like complete daily-use tools while keeping
storage as ordinary Markdown/files.

Tasks:

- [x] improve Notes list filtering, sorting, and filtered empty states;
- [x] improve Notes rename/conflict UX;
- [x] add Notes delete/trash through Files API with confirmation;
- [x] add Files restore metadata view;
- [x] add Files restore command;
- [x] define external open/show-in-folder as a public v2 API;
- [x] add watcher-based refresh for Files/Notes after external changes;
- [x] add safe binary read/streaming contract.

Status: done.

### Phase 3 - Sync Hardening

Goal: make local-first cross-device file/workspace sync reliable and harden the
optional self-hosted relay without making it the source of vault truth.

Verified in the current implementation:

- [x] define conflict UX contract for desktop and sync plugin;
- [x] add server/device revocation checks for sync auth paths;
- [x] persist and display sync errors in Sync plugin;
- [x] add retry/backoff for sync client operations;
- [x] persist an atomic core snapshot under `.verstak/sync/`;
- [x] reconcile initial vaults safely;
- [x] apply pulled operations strictly by `server_sequence`;
- [x] sync workspace create, rename, trash, and restore through core-owned
  entity with durable `workspaceId`;
- [x] add real two-vault smoke scenarios;
- [x] document deployment and backup procedures for sync-server;
- [x] bind sync-server to loopback by default, set HTTP timeouts/graceful
  shutdown, publish health/readiness/build data;
- [x] bounded JSON/push fields and pull pages;
- [x] add streamed Blob transport with SHA-256/size verification;
- [x] hash tokens, persist sessions, require CSRF for browser mutations;
- [x] add embedded sync-server web console with shared responsive templates;
- [x] remove hardcoded server HTML, split into shared layout/sidebar plus
  per-section templates.

Known limits:

- [x] Files plugin API remains bounded to 2 MB text / 8 MB byte reads.
- [x] External rename is represented as delete + create.
- [ ] Operation-log retention/compaction is intentionally deferred.
- [ ] Secrets, plugin settings, Todo, Journal, Activity, and Browser Inbox are
  not synchronized.

Status: core sync foundations complete. Retention and additional data domains
are future milestones.

### Phase 4 - Preview, Search, Activity, Journal

Goal: add the next visible product layer as replaceable plugins.

Tasks:

- [x] keep Markdown preview inside `verstak.default-editor`, with no separate
  provider competing for `.md` files;
- [x] implement basic image metadata preview plugin;
- [x] implement baseline `verstak.search` workspace plugin;
- [x] add type-as-you-search behavior and vault path/name matches;
- [x] implement baseline `verstak.activity` event log plugin;
- [x] expose Activity and Browser Inbox as global sidebar views;
- [x] implement persistent search index and cross-provider runtime hosting;
- [x] implement activity reconstruction and worklog suggestions;
- [x] implement journal/worklog plugin that can consume activity suggestions.

Status: done. Remaining work is UX depth (Today flow, reporting, timers).

### Phase 5 - Browser Inbox

Goal: capture browser context into the local vault through a public local
receiver and an official inbox plugin.

Tasks:

- [x] define browser capture payload protocol;
- [x] implement minimal `verstak.browser-inbox` plugin;
- [x] implement browser extension capture scaffold;
- [x] define local receiver permission/pairing model;
- [x] require an installation-local pairing token;
- [x] add domain-to-workspace binding;
- [x] convert inbox entries into notes through public plugin APIs;
- [x] record converted inbox entries in Activity;
- [x] convert inbox entries into link files;
- [x] convert captured text file attachments;
- [x] convert captured bounded binary attachments.

Status: done. Remaining work: capture-from-clipboard/manual capture,
chunked large-file capture.

### Phase 6 - Secrets

Goal: provide protected storage for credentials without turning secrets into
notes or plain files.

Tasks:

- [x] define secret-store capability and permissions;
- [x] implement encrypted local secret storage;
- [x] add UI-only official secrets plugin;
- [x] integrate secret references with workspaces.

Status: done.

### Phase 7 - Sidecar/Sandbox Boundary

Goal: move from trusted bundled plugin JavaScript toward safer plugin execution.

Tasks:

- [ ] implement sidecar launch protocol and local RPC;
- [ ] permission-scope sidecar APIs;
- [ ] stop sidecars on plugin disable;
- [ ] surface sidecar logs and health in Plugin Manager;
- [ ] document supported sidecar languages and packaging rules.

Status: not started.

### Phase 8 - Packaging, Update, Release

Goal: produce installable, recoverable releases.

Tasks:

- [x] define release artifact matrix (desktop, plugins, SDK, sync server,
  browser extension);
- [x] add build scripts for .deb, AppImage, Windows portable, and plugin
  packages;
- [ ] add plugin package signing/verification or equivalent integrity checks;
- [x] add backup/restore docs for vault and sync server;
- [ ] add crash/log collection for local diagnostics;
- [ ] build release smoke checklist.

Status: packaging scripts exist and produce release artifacts. Signing,
auto-update, and release smoke checklist are future work.

## 5. Immediate Execution Order

1. [x] Command Palette UI host.
2. [x] Status bar item host.
3. [x] External open public API.
4. [x] Notes trash/delete UX.
5. [x] Sync hardening pass.
6. [x] Browser inbox protocol, extension scaffold, local receiver, inbox plugin,
   and conversions.
7. [ ] Product UX follow-up: make the shell-level Today flow the command center
   for captures, recent activity, Activity worklog suggestions, and Journal
   import/review. This should reuse existing official plugin contracts instead
   of moving Activity, Browser Inbox, or Journal into desktop core.

## 6. Stop Conditions

Work can continue autonomously until one of these occurs:

- a decision requires product policy not present in docs;
- implementation needs credentials, signing keys, or external infrastructure;
- a repeated blocker appears after three evidence-based attempts;
- a repository has user changes that directly conflict with the next edit.

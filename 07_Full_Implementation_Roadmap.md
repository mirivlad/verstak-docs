# Verstak2 Full Implementation Roadmap

## 1. Goal

Bring Verstak2 to a complete standalone local-first desktop product:

- core platform and UI shell can run without official plugins;
- official plugins provide the user-facing tools;
- vault data stays human-readable and local-first;
- sync UI/settings, browser capture, activity, journal, preview, search, and
  secrets are plugin/runtime extensions; sync correctness (scanner, operation
  log, reconciliation, and workspace identity) stays in Desktop core;
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
- Files Core API with safe path policy, durable snapshot scanning, and core sync
  operation recording;
- public `files.openExternal` / `files.showInFolder` API and Files plugin usage;
- mode-aware Workbench open/edit provider routing and default editor plugin;
- official Files plugin, Notes plugin, Markdown Editor plugin, Search plugin,
  Sync plugin, and platform-test plugin;
- browser inbox local receiver and minimal official Browser Inbox plugin;
- sync server with device/user auth and operation push/pull;
- SDK manifest/types/schema coverage for current plugin APIs;
- persisted System/English/Russian application language selection, localized
  desktop shell, public `api.i18n` plugin contract, and bilingual catalogs for
  all official plugins;
- automated Go, frontend, official plugin, SDK, and real-sync smoke checks.

Known remaining gaps:

- `fileActions`, `noteActions`, and `contextMenuEntries` are exposed through the
  desktop contribution summary and hosted by the official Files/Notes surfaces.
- Sidecar host is not implemented.
- Files/Notes are usable but not complete: chunked streaming/large-file import,
  richer conflict UX, and remaining Notes polish are still incomplete.
- Activity, Journal, Browser Inbox conversion workflows, indexed Search, and
  Secrets now have baseline plugin implementations and public API contracts.
  Their remaining work is product UX depth: richer Today aggregation,
  actionable Activity to Journal review flows, capture-from-clipboard/manual
  capture, production-grade reporting, and final polish.
- Templates plugin is not implemented yet.
- File/image preview exists as a basic provider with bounded inline image
  rendering through the public Files API.
- Browser extension repository has protocol, queue, and Chromium/Firefox build
  scaffold; desktop has a bounded, token-paired local receiver and mounted-view
  inbox plugin; receiver pairing settings, basic Browser Inbox domain binding,
  create-note conversion, and
  create-link conversion are implemented, text file attachment conversion is
  implemented, bounded binary attachment conversion is implemented, and Activity
  records conversions. Chunked large-file attachment capture remains future
  work.
- Packaging/update/release workflow is not product-grade yet.
- Browser extension UI localization is not yet migrated to the shared
  multilingual product policy.

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

Goal: make local-first cross-device file/workspace sync reliable and harden the
optional self-hosted relay without making it the source of vault truth.

Verified in the current implementation:

- [x] define conflict UX contract for desktop and sync plugin;
- [x] add server/device revocation checks for sync auth paths;
- [x] persist and display sync errors in Sync plugin;
- [x] add retry/backoff for sync client operations;
- [x] persist an atomic core snapshot under `.verstak/sync/`; scan on vault
  open, before manual sync, and after watcher debounce; exclude internal paths,
  trash, temporary files, and symlinks;
- [x] reconcile initial vaults safely: pull before local bootstrap, never turn
  an empty initial snapshot into deletes, and stop on an incompatible
  local/remote path conflict;
- [x] apply pulled operations strictly by `server_sequence`, stop at the first
  failed operation, retain cursor/retry state across restart, and avoid watcher
  echo after a successful remote apply;
- [x] sync workspace/Deal create, rename, trash, and restore through a
  core-owned entity carrying the durable `workspaceId` rather than exposing the
  workspace marker to plugins;
- [x] add real two-vault smoke scenarios for external create/update/delete,
  scanner-based rename representation, no remote echo, and workspace lifecycle;
- [x] document deployment and backup procedures for `verstak-sync-server`.
- [x] bind sync-server to loopback by default, set HTTP timeouts/graceful
  shutdown, publish health/readiness/build data, and document nginx/Caddy
  trusted-proxy deployment;
- [x] bound JSON/push fields and pull pages, return stable public error codes,
  and make Desktop stop/persist cursor at the first failed page operation;
- [x] add streamed Blob transport with SHA-256/size verification, atomic local
  apply, per-user/vault ownership references, file/quota limits, and immediate
  revoked-device denial;
- [x] hash newly issued device, session, confirmation, and reset tokens;
  persist sessions, require CSRF for browser mutations, and use transactions
  for pairing, credential, blob, and multi-table user/device changes.
- [x] add an embedded, dependency-free sync-server web console with shared
  responsive templates for public/account/admin flows, Russian/English/system
  locale preference, user device revoke, and operational admin sections for
  users, devices, vaults, storage, audit, SMTP settings, and diagnostics;
  protect its mutations with sessions, CSRF, security headers, and
  administrator re-authentication for sensitive changes.
- [x] remove the former hardcoded server HTML and split the embedded console
  into shared layout/sidebar plus public, account, and per-admin-section
  templates; add locale-aware timestamps, local confirmation dialog, safe
  public-form CSRF, server-side filters/sorting/pagination, user email
  confirmation/device lifecycle actions, one-time generated admin password
  resets without URL/initial-HTML/audit/cookie/plaintext persistence, vault metadata diagnostics without file
  payloads, sanitised diagnostics download, and an interactive headless-
  Chromium smoke script without npm dependencies.

Known limits in this phase:

- [x] The Files plugin API remains bounded to 2 MB text / 8 MB byte reads;
  core sync itself sends binary/larger files through the Blob API. Files over
  configured Blob/quota limits remain persistent visible warnings and are not
  marked synchronized.
- [x] External rename is represented as delete + create; it is not a
  cross-device rename detector for ordinary files.
- [ ] Automatic conflict resolution is intentionally absent. Operation-log
  retention/compaction is also intentionally deferred: without a server
  checkpoint/materialized state and proven device recovery cursors, pruning
  operations could make a newly paired device unrecoverable. Safe cleanup is
  limited to sessions/tokens/idempotency/audit/temp uploads/rate buckets.
- [ ] Secrets, plugin settings, Todo, Journal, Activity, and Browser Inbox are
  not synchronized in this phase.
- [ ] The embedded control plane intentionally remains server-rendered. A
  separate milestone may improve its visual design or add richer client-side
  interactions, but must preserve the local-first desktop model and server-side
  authorization/CSRF checks.

Verification:

- sync server `go test ./...`, `go vet ./...`, systemd validation and a local
  release-package smoke;
- desktop unit/API tests and real two-vault smoke including a binary above the
  former inline limit;
- SDK schema/type checks and official Sync plugin build/localization checks.

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

Status: baseline platform/product contracts are implemented. Remaining work is
tracked as UX follow-up rather than missing runtime foundation: Today should
make Activity suggestions and Journal imports actionable from the first
workspace screen, and Journal still needs reporting/timer/export depth.

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
- [x] require an installation-local pairing token and expose its rotation through
  Browser Inbox settings;
- [x] bound browser receiver payloads and file content before publishing events;
- [x] add domain-to-workspace binding;
- [x] convert inbox entries into notes through public plugin APIs;
- [x] record converted inbox entries in Activity through public plugin events;
- [x] convert inbox entries into link files through public plugin APIs;
- [x] convert captured text file attachments through public plugin APIs;
- [x] convert captured bounded binary attachments through public plugin APIs.

Verification:

- extension build checks;
- local receiver API tests;
- inbox plugin smoke/e2e tests.

Status: baseline capture, pairing, routing, conversion, and Activity recording
workflows are implemented. Remaining work is UX follow-up:
capture-from-clipboard/manual capture, domain binding state, and conversion
outcomes in the visible app flow.

### Phase 6 - Secrets

Goal: provide protected storage for credentials without turning secrets into
notes or plain files.

Tasks:

- [x] define secret-store capability and permissions;
- [x] implement encrypted local secret storage;
- [x] add UI-only official secrets plugin;
- [x] integrate secret references with workspaces without exposing raw values to
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
5. [x] Sync hardening pass: snapshots/reconciliation, workspace identity,
   bounded pagination, Blob transport/ownership/quota, secure token/session
   policy, and expanded real two-vault smoke. Checkpoint-based operation
   retention and additional data domains remain future work.
6. [x] Browser inbox protocol design, extension scaffold, local receiver,
   minimal inbox plugin, and note/link/text-file/binary-file conversions are
   implemented.
7. [ ] Product UX follow-up in `verstak-desktop`: make the shell-level Today
   flow the command center for captures, recent activity, Activity worklog
   suggestions, and Journal import/review. This should reuse existing official
   plugin contracts instead of moving Activity, Browser Inbox, or Journal into
   desktop core.

This order finishes generic platform surfaces before building product features
that depend on them.

## 6. Stop Conditions

Work can continue autonomously until one of these occurs:

- a decision requires product policy not present in docs;
- implementation needs credentials, signing keys, or external infrastructure;
- a repeated blocker appears after three evidence-based attempts;
- a repository has user changes that directly conflict with the next edit.

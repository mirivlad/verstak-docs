# Persistent Search Index And Runtime Provider Hosting Design

## Context

Phase 4 requires `verstak.search` to move beyond live recursive scans:

- keep search as an official plugin, not a core feature;
- persist a workspace-scoped search index;
- host `searchProviders` contributed by other plugins at runtime;
- preserve the local-first, readable vault model;
- avoid copying code or architecture from the old Verstak repository.

Current implementation status:

- `verstak.search` is a workspace item and contributes `searchProviders`;
- it searches while typing by walking files through `api.files.list`;
- it reads text-like files through `api.files.readText`;
- it opens file results through `api.workbench.openResource`;
- the contribution registry already exposes `searchProviders`;
- `api.commands.executeFor(pluginId, commandId, args)` already hosts frontend
  provider handlers for other contribution types;
- desktop backend already has plugin-scoped JSON data methods
  `ReadPluginDataJSON` and `WritePluginDataJSON`, but the frontend plugin API
  currently exposes only `settings`.

No visual companion is needed for this design because the decision is about
runtime contracts and data flow, not layout.

## Assumptions

- The next implementation should be a small reversible platform step.
- Search remains replaceable plugin functionality; core should expose generic
  storage and contribution execution only.
- `searchProviders[].handler` is treated as a command id. A provider plugin
  must declare that command in `contributes.commands` and register its frontend
  handler with `api.commands.register`.
- The initial persistent index is JSON-backed plugin data, not SQLite FTS and
  not a background sidecar.
- The index is an optimization and discovery layer. User files remain the
  source of truth.

## Alternatives Considered

### Recommended: plugin-owned index plus command-backed provider hosting

`verstak.search` owns its local index in plugin storage, uses public Files API
and events to keep it fresh, and fans out to contributed providers with
`api.commands.executeFor`.

Trade-offs:

- smallest core/runtime change;
- matches existing Files/Notes contribution execution pattern;
- keeps user-facing search outside core;
- JSON index is simpler than full text search but sufficient for the current
  roadmap item.

### Core search service

Desktop core would own indexing and execute provider searches.

Trade-offs:

- easier to centralize later ranking and indexing;
- violates the current direction that search is a plugin-level user feature;
- makes core understand official search semantics too early.

### Sidecar or SQLite FTS indexer now

Introduce a dedicated indexer process or SQLite FTS schema immediately.

Trade-offs:

- better long-term scalability;
- too large for the current milestone;
- adds migration, lifecycle, and sync/cache policy decisions before the basic
  provider runtime contract is proven.

## Chosen Design

Use the recommended approach.

`verstak.search` becomes both:

- the workspace search UI;
- the runtime host for all enabled `searchProviders`.

The desktop and SDK expose a generic frontend storage surface:

```ts
api.storage.data.read(name: string): Promise<Record<string, unknown>>
api.storage.data.write(name: string, data: Record<string, unknown>): Promise<void>
```

This maps to existing plugin-scoped backend methods. It requires
`storage.namespace`, follows current plugin ownership rules, and does not let a
plugin read another plugin's namespace.

The Search plugin stores its persistent index as plugin data named
`search-index`. Settings remain for user preferences only.

## Provider Runtime Contract

`searchProviders` keep their current manifest shape:

```json
{
  "id": "verstak.search.vault-text",
  "label": "Vault Text Search",
  "handler": "verstak.search.searchVaultText"
}
```

The `handler` value must name a command declared by the same plugin:

```json
{
  "contributes": {
    "commands": [
      {
        "id": "verstak.search.searchVaultText",
        "title": "Search Vault Text",
        "handler": "searchVaultText"
      }
    ],
    "searchProviders": [
      {
        "id": "verstak.search.vault-text",
        "label": "Vault Text Search",
        "handler": "verstak.search.searchVaultText"
      }
    ]
  }
}
```

The provider registers the command handler at mount time:

```js
api.commands.register('verstak.search.searchVaultText', searchVaultText)
```

Runtime availability:

- this milestone does not auto-start unloaded frontend bundles or sidecars;
- a provider is executable only after its command handler is registered in the
  current frontend runtime;
- declared but unregistered providers are skipped and reported as unavailable;
- later sidecar/background activation can extend this without changing the
  provider manifest shape.

Provider input:

```ts
{
  source: 'search',
  providerId: string,
  query: string,
  workspaceRootPath: string,
  limit: number
}
```

Provider output:

```ts
{
  results: SearchResult[]
}
```

`SearchResult`:

```ts
{
  id?: string,
  path?: string,
  title?: string,
  snippet?: string,
  matchType?: string,
  providerId?: string,
  providerLabel?: string,
  type?: 'file' | 'folder' | 'activity' | 'worklog' | string,
  openable?: boolean,
  line?: number,
  score?: number,
  resource?: {
    kind: 'vault-file',
    path: string,
    mode?: 'view' | 'edit'
  }
}
```

The Search host normalizes missing optional fields. Invalid provider responses
are ignored with a visible status warning; they do not fail the whole search.

## Persistent Index Shape

The first index version is intentionally small:

```json
{
  "version": 1,
  "workspaceRootPath": "Project",
  "builtAt": "2026-06-29T00:00:00Z",
  "entries": [
    {
      "path": "Project/Docs/case.md",
      "name": "case.md",
      "type": "file",
      "extension": "md",
      "size": 1234,
      "modifiedAt": "2026-06-29T00:00:00Z",
      "text": "short normalized searchable text or snippet"
    }
  ]
}
```

Rules:

- index only the current workspace root;
- store vault-relative slash paths;
- index folders and regular files;
- read content only for text-like files already handled by current Search;
- rely on the host `readText` limit for large text files;
- store short normalized text, not full arbitrary binary data;
- rebuild when version or workspace root differs.

## Index Lifecycle

On mount:

1. Read `api.storage.data.read('search-index')`.
2. If version/root matches, use it immediately.
3. If missing or stale, build an index from `api.files.list` and text reads.
4. Write the built index with `api.storage.data.write`.
5. Subscribe to `file.changed`.

On `file.changed`:

- if event path is outside the workspace, ignore it;
- for create/update, refresh that path's metadata/content if readable;
- for delete/trash, remove the path and descendants;
- for move, remove `fromPath` when present and refresh the new path;
- write the updated index after the change is applied.

If an incremental update fails, mark the index stale in UI and continue serving
the last usable index until rebuild succeeds.

## Search Flow

For a query shorter than two characters, return no results.

For a valid query:

1. Query local persistent index for path, name, folder, and text matches.
2. List enabled `searchProviders` through `api.contributions.list`.
3. Call each provider except duplicates that would recurse into the same
   in-flight command.
4. Merge and normalize results.
5. Sort by score, then provider order, then path/title.
6. Render provider label, match type, path/title, snippet, and open action when
   the result has a supported resource.

Provider failures are isolated. The status line reports how many providers
failed without hiding successful results.

## Error Handling

- Missing `storage` API: fall back to live scanning and show a degraded status.
- Missing `storage.namespace` permission: Search runs without persistence and
  reports degraded persistence.
- Corrupt index JSON: ignore it, rebuild, and overwrite only after a successful
  rebuild.
- Provider command not declared or not registered: skip that provider and show a
  warning count.
- File read errors: skip that file, matching the current Search behavior.
- Event subscription errors: keep search usable, mark index refresh as manual.

## Testing And Verification

Expected test coverage:

- SDK types include `api.storage.data.read/write` and search result/provider
  contracts.
- SDK mock API stores plugin data separately from settings.
- Desktop frontend bridge exposes `api.storage.data.read/write`.
- Desktop bridge smoke test verifies plugin data round-trip through Wails mock.
- Search plugin smoke test verifies:
  - persisted index is read before scanning;
  - missing/stale index triggers build and write;
  - query uses persisted entries;
  - `file.changed` updates or removes entries;
  - provider fan-out uses `contributions.list('searchProviders')` and
    `commands.executeFor`;
  - provider failure does not hide local results.
- Roadmap and official plugin docs are updated after implementation.

Manual smoke after implementation:

- start desktop frontend/dev flow used by the repository;
- open Search workspace item;
- search a known text file;
- reload/remount Search and confirm results come from stored index;
- enable a test provider and confirm its results appear with provider label.

## Out Of Scope

- SQLite FTS;
- typo/layout tolerant search;
- binary OCR or PDF extraction;
- background sidecar indexing;
- cross-workspace global search;
- sync policy for index cache;
- journal/worklog/activity reconstruction implementation.

Those remain later roadmap items.

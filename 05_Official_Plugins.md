# Official Plugins

Официальные плагины - это базовый набор инструментов Верстака. Они не должны быть скрытыми частями core. Их задача - показать, что платформа действительно работает через capabilities и contribution points.

## 1. `official.files`

Назначение:

- дерево/список файлов внутри дела;
- добавление файлов;
- перемещение/копирование в vault;
- открытие системным приложением;
- file metadata;
- file actions registry consumer.

Provides:

```text
workspace.files
vault.files
entity.file
file.browser
```

Optional requires:

```text
editor.text
viewer.file
preview.file
search.provider
```

Поведение:

- если есть подходящий editor capability, показывает "Edit";
- если есть viewer/preview capability, показывает "Preview";
- если подходящего provider/capability нет, показывает понятное no-provider
  состояние; открытие внешним приложением остается отдельной отложенной
  возможностью.

## 2. `official.notes`

Назначение:

- markdown notes as a UI-level context over ordinary Markdown files;
- canonical `Notes/` folder inside case/project;
- `Overview.md` is allowed only as an ordinary Markdown filename, not as a
  special UI entity;
- note metadata;
- note links.

Provides:

```text
workspace.notes
note.registry
```

Requires:

```text
vault.files
```

Optional requires:

```text
editor.text.markdown
preview.markdown
search.provider
```

Важное правило:

- title и filename должны оставаться синхронизированными;
- filename - человекочитаемая проекция title;
- при конфликте имени не добавлять `_2` молча, а показывать понятный conflict dialog.

## 3. `official.markdown-editor`

Назначение:

- редактирование markdown/text;
- toolbar;
- save flow;
- dirty state;
- keyboard shortcuts.

Provides:

```text
editor.text
editor.text.markdown
editor.note.markdown
```

Optional requires:

```text
link.resolver
```

Не должен:

- сам решать, где хранятся notes;
- напрямую зависеть от `official.notes`;
- тащить file manager внутрь себя.

Markdown preview is part of the Markdown editor surface. There is no separate
official Markdown preview plugin, because a standalone view provider would
compete with the editor routing for `.md` / `.markdown` files.

## 4. `official.file-preview`

Назначение:

- inline preview for image files through bounded `api.files.readBytes`;
- metadata view for previewed files;
- `Open External` action through `api.files.openExternal`.

Provides:

```text
viewer.file
viewer.image
preview.file
```

Текущий статус: базовый `verstak.file-preview` renders image files inline via
the public Files API and shows file metadata. Text-like files, code, and
Markdown stay with editor plugins.

## 5. `official.activity`

Назначение:

- сбор activity events;
- отображение истории;
- реконструкция работы;
- подсказки для worklog.

Provides:

```text
activity.log
activity.provider
activity.reconstruction
```

Subscribes:

```text
file.opened
file.changed
note.saved
action.started
browser.capture.received
case.selected
browser.capture.page
browser.capture.selection
browser.capture.link
```

Текущий статус: базовый `verstak.activity` implemented as both a global sidebar
view and a workspace item. Workspace tabs store and display only their own
activity stream; the global sidebar view aggregates activity from all workspace
streams plus unscoped global activity. It contributes `activityProviders`; the
desktop runtime hosts those providers and records subscribed public events into
the plugin storage even when the Activity view is not mounted. The Activity UI
is a read/clear surface, not a manual recording toggle. It now reconstructs
compact worklog suggestions from scoped activity streams and exposes them
through the command-backed `verstak.activity.suggestWorklog` runtime contract
for the future Journal plugin.

## Sync Conflict UX Contract

`api.sync.now()` returns warning details through `conflicts` and `applyErrors`.
The official Sync plugin must display both as warnings after manual sync. A
conflict warning must include at least the affected entity type/path when the
server provides those fields. The plugin must not auto-resolve conflicts, rename
local files, overwrite local files, or hide conflict details behind a plain
count.

## 6. `official.journal`

Назначение:

- ручной журнал работ;
- billable/non-billable;
- отчеты по делу/клиенту;
- принятие suggested time из activity.

Provides:

```text
worklog
journal
report.worklog
```

Optional requires:

```text
activity.reconstruction
```

Текущий статус: базовый `verstak.journal` implemented as both a global sidebar
view and a workspace item. Workspace views store manual worklog entries in the
plugin settings namespace, import non-billable entries from
`verstak.activity.suggestWorklog`, and deduplicate repeated imports by Activity
suggestion id. The global view aggregates stored workspace worklogs. Billing
reports, invoice export, timers, and richer report filters are still future
work.

## 7. `official.browser-inbox`

Назначение:

- прием ссылок, выделенного текста, страниц и snippets из browser extension;
- pending queue;
- привязка доменов к делам;
- создание inbox entries;
- превращение inbox entry в note/link/file/activity.

Provides:

```text
capture.browser
browser.inbox
domain.binding
```

Requires:

```text
network.local
```

Optional requires:

```text
workspace.notes
activity.log
search.provider
```

Текущий статус: базовый `verstak.browser-inbox` implemented as both a global
sidebar view and a workspace item. Workspace tabs keep their own pending queue;
the global sidebar view aggregates queues from all workspaces plus unscoped
global captures. The local receiver now has an opt-in paired mode that requires
`X-Verstak-Receiver-Token` before publishing browser capture events. Browser
Inbox stores plugin-owned `domainBindings` and routes unscoped captures with an
exact domain match into the bound workspace queue. Its first conversion workflow
creates ordinary Markdown notes through the public Files API and publishes a
`browser.capture.converted` event, which Activity records through its public
provider subscription. Browser Inbox also creates human-readable `.url` link
files through the public Files API. File attachment capture/conversion is still
future work.

## 9. `official.search`

Назначение:

- workspace-scoped search UI;
- baseline recursive text search through public Files API;
- search provider contribution for platform discovery;
- index notes/files/activity/worklog later;
- typo/layout tolerant search later.

Provides:

```text
search
search.provider
search.indexer
```

Текущий статус: базовый `verstak.search` implemented as a workspace item and
`searchProviders` contribution. It searches as the user types, matches vault
file/folder names and paths, scans text-like file contents through
`api.files.list` / `api.files.readText`, and opens file results through
Workbench. It persists a workspace-scoped JSON search index in the plugin data
namespace, refreshes it from public file events, registers its own vault-text
provider as a command-backed `searchProviders` handler, and fans out to other
registered provider commands at runtime. Full-text ranking, typo/layout
tolerant search, and sidecar indexing remain later work.

Target UX: search should be available from the workspace header next to the
workspace title. The standalone Search workspace item may remain only as an
expanded results surface; it should not be the primary search entry point.

## 10. `official.secrets`

Назначение:

- защищенное хранилище клиентских доступов;
- SSH/CMS/VPS/database/API secrets;
- bridge secret, sync token, device private key, pairing token;
- permissions for secret access.

Provides:

```text
secret-store
secrets.read-ui
secrets.write-ui
```

Важное правило:

- секреты не должны храниться как обычный markdown/plain text;
- доступ к secret-store должен идти через permissions;
- плагины не получают `secrets.read` автоматически.

## 11. `official.templates`

Назначение:

- шаблоны дел;
- client/project/server/device structures;
- initial folder/note/action layout.

Provides:

```text
case.templates
```

Optional requires:

```text
workspace.notes
workspace.files
```

## 12. Первый минимальный набор

Для первого платформенного этапа достаточно:

- `official.files`;
- `official.notes`;
- `official.markdown-editor`;
- `official.file-preview`;
- `official.activity`;
- `official.browser-inbox`;

Но все они должны быть настоящими динамическими плагинами, даже если поставляются вместе с приложением.

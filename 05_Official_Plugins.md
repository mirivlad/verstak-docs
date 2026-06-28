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
is a read/clear surface, not a manual recording toggle. Reconstruction and
worklog suggestions are still future work.

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
global captures. Pairing, domain binding, and conversion into
notes/links/files/activity are still future work.

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
Workbench. Persistent indexing and cross-provider runtime hosting are still
future work.

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

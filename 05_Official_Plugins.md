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
preview.markdown
```

Не должен:

- сам решать, где хранятся notes;
- напрямую зависеть от `official.notes`;
- тащить file manager внутрь себя.

## 4. `official.markdown-preview`

Назначение:

- read-only markdown render through a Workbench `openProviders` contribution;
- `mode: "view"` support so edit routing remains with editor plugins;
- safe baseline markdown rendering before optional syntax highlight/link
  resolver integration.

Provides:

```text
preview.markdown
viewer.markdown
```

Optional requires:

```text
link.resolver
```

Текущий статус: базовый `verstak.markdown-preview` implemented as an official
view-only provider for `.md` / `.markdown` files.

## 5. `official.file-preview`

Назначение:

- просмотр изображений;
- просмотр text-like файлов;
- базовый PDF/image metadata preview, если возможно;
- fallback to system open.

Provides:

```text
viewer.file
viewer.image
viewer.text
preview.file
```

## 6. `official.activity`

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
```

## 7. `official.journal`

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

## 8. `official.browser-inbox`

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

## 9. `official.search`

Назначение:

- общий поиск по vault;
- индекс notes/files/activity/worklog;
- providers from plugins;
- typo/layout tolerant search later.

Provides:

```text
search
search.provider
search.indexer
```

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
- `official.markdown-preview`;
- `official.activity`;
- `official.browser-inbox`;

Но все они должны быть настоящими динамическими плагинами, даже если поставляются вместе с приложением.

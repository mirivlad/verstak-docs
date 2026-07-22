# Official Plugins

Официальные плагины — базовый набор инструментов Верстака. Они используют тот же
plugin runtime, что и сторонние. Их задача — показать, что платформа работает
через capabilities и contribution points.

Все официальные плагины используют префикс `verstak.*` в id.

## 1. `verstak.files`

Назначение:

- дерево/список файлов внутри дела;
- добавление файлов и папок;
- перемещение/переименование;
- открытие через Workbench (openProvider routing);
- trash/restore (через `verstak.trash`);
- file metadata.

Provides:

```
workspace.files
vault.files
entity.file
file.browser
```

Optional requires:

```
editor.text
viewer.file
preview.file
search.provider
```

Текущий статус: реализован. Открывает файлы через `api.workbench.openResource()`,
не импортирует редактор напрямую. Корзина выделена в отдельный плагин `verstak.trash`.

## 2. `verstak.notes`

Назначение:

- markdown notes как UI-слой над обычными `.md` файлами;
- каноническая папка `Notes/` внутри дела;
- `Overview.md` — обычное markdown-имя файла, не специальная UI-сущность;
- note metadata;
- rename с синхронизацией title/filename;
- conflict dialog при конфликте имён.

Provides:

```
workspace.notes
note.registry
```

Requires:

```
verstak/core/files/v1
```

Optional requires:

```
editor.text.markdown
search.provider
```

Текущий статус: реализован. Title и filename синхронизированы. При конфликте
имени показывается conflict dialog.

## 3. `verstak.default-editor`

Назначение:

- редактирование текста и markdown;
- toolbar;
- save flow;
- dirty state;
- markdown preview (встроен, не отдельный плагин);
- keyboard shortcuts (Ctrl+S).

Provides:

```
editor.text
editor.text.markdown
editor.note.markdown
```

Optional requires:

```
link.resolver
```

Текущий статус: реализован как единый плагин с тремя openProviders
(`text`, `generic-markdown`, `notes-markdown`). Использует `api.files.readText` /
`api.files.writeText`. Markdown preview — часть редактора, без отдельного
плагина предпросмотра.

## 4. `verstak.file-preview`

Назначение:

- inline preview для изображений через `api.files.readBytes`;
- metadata view;
- `Open External` через `api.files.openExternal`.

Provides:

```
viewer.file
viewer.image
preview.file
```

Текущий статус: базовый рендеринг изображений через публичный Files API,
плюс metadata файла. Текстовые файлы, код и markdown остаются за
editor-плагинами.

## 5. `verstak.activity`

Назначение:

- сбор activity events;
- отображение истории активности;
- реконструкция работы;
- worklog suggestions для Journal.

Provides:

```
activity.log
activity.provider
activity.reconstruction
```

Subscribes:

```
file.opened
file.changed
note.saved
action.started
browser.capture.received
case.selected
```

Текущий статус: реализован как глобальный sidebar view и workspace item.
Workspace tabs хранят свою activity stream; глобальный view агрегирует все
workspace streams. Предоставляет `activityProviders`; desktop runtime записывает
события в plugin storage даже когда Activity view не смонтирован. Реконструирует
worklog suggestions через контракт `verstak.activity.suggestWorklog`.

## 6. `verstak.journal`

Назначение:

- ручной журнал работ;
- billable/non-billable;
- приём suggested time из activity;
- создание записи из завершённого todo.

Provides:

```
worklog
journal
report.worklog
```

Optional requires:

```
activity.reconstruction
```

Текущий статус: реализован как глобальный sidebar view и workspace item.
Хранит записи в plugin settings namespace, импортирует не-billable записи
из `verstak.activity.suggestWorklog`, дедуплицирует по Activity suggestion id.

## 7. `verstak.browser-inbox`

Назначение:

- приём страниц, ссылок, выделенного текста и файлов из browser extension;
- pending queue с scoping по workspace;
- domain bindings;
- конвертация inbox entry в note/link/file;
- запись конвертаций в Activity.

Provides:

```
capture.browser
browser.inbox
domain.binding
```

Requires:

```
network.local
```

Optional requires:

```
workspace.notes
activity.log
search.provider
```

Текущий статус: реализован как глобальный sidebar view и workspace item.
Local receiver в paired mode с токеном. Поддерживает конвертацию в note
(через публичный Files API), link (`.url` файлы), text file attachments
и bounded binary attachments. Конвертации записываются в Activity.

## 8. `verstak.search`

Назначение:

- workspace-scoped search;
- поиск по мере ввода;
- поиск по именам файлов/папок и содержимому текстовых файлов;
- persistent search index;
- cross-provider runtime hosting.

Provides:

```
search
search.provider
search.indexer
```

Текущий статус: реализован как workspace item и `searchProviders` contribution.
Ищет по мере ввода, индексирует vault, обновляет индекс по файловым событиям,
поддерживает других search providers через runtime.

## 9. `verstak.secrets`

Назначение:

- защищённое хранилище доступов;
- workspace-scoped secrets;
- master password (AES-GCM).

Provides:

```
secret-store
secrets.read-ui
secrets.write-ui
```

Текущий статус: реализован. Desktop core имеет AES-GCM secret store,
разблокируемый один раз за сессию. Плагин показывает global и workspace-scoped
секреты, поддерживает редактирование, удаление, копирование markdown secret links.
Рендерит `verstak-secret://...` ссылки.

## 10. `verstak.todo`

Назначение:

- списки задач внутри дел и глобально;
- статусы: open, done, cancelled;
- приоритеты, due date, reminders;
- создание Journal записи из завершённого todo.

Provides:

```
workspace.todo
```

Текущий статус: реализован. Reminders с нативными desktop-уведомлениями
(при наличии capability `verstak/core/notifications/v1`). Поддерживает
создание Journal записи из todo с копированием фактических данных.

## 11. `verstak.trash`

Назначение:

- глобальный просмотр удалённых файлов;
- восстановление из корзины;
- перманентное удаление.

Provides:

```
trash.management
```

Текущий статус: реализован как глобальный sidebar view. Работает
с internal trash storage (`.verstak/trash/files/`).

## 12. `verstak.sync`

Назначение:

- ручная синхронизация vault;
- отображение статуса и конфликтов;
- настройки подключения к sync server.

Provides:

```
sync.ui
```

Requires:

```
network.remote
```

Текущий статус: реализован как глобальный sidebar view и settings panel.
Показывает vaultId, статус, unpushed count, ошибки и конфликты.
Не делает auto-resolve конфликтов.

## 13. `verstak.templates`

Назначение:

- шаблоны дел при создании;
- предопределённые наборы workspace tools;
- one-time применение (шаблон не привязан к делу после создания).

Provides:

```
case.templates
```

Текущий статус: реализован через built-in templates в desktop core
(General, Project, Writing, Admin, Minimal). Модальное окно создания
дела показывает описание шаблона и его вкладки.

## 14. `verstak.import`

Назначение:

- импорт актуального содержимого DokuWiki и Obsidian из выбранной папки или
  архива;
- анализ без записи в vault;
- предложение редактируемой структуры папок, дел, заметок и файлов;
- применение только после явного подтверждения пользователя.

Provides:

```
verstak/import/v1
```

Requires:

```
verstak/core/import/v1
```

Плагин открывается через **Plugin Manager → Import → Settings** и проводит
пользователя через четыре шага: выбор источника, анализ, проверка структуры,
импорт. Предложение адаптивно сохраняет смысловые ветви, распознаёт простые
проектные деревья, а несгруппированные материалы помещает в дело `Без папки`.
Пользователь может переименовать узел, изменить его тип или исключить его до
применения плана.

DokuWiki импортирует только текущие `data/pages/**/*.txt` и `data/media/**`.
История и служебные данные не включаются. Страницы переводятся из wiki-разметки
в Markdown: заголовки, списки, таблицы, горизонтальные линии, code/file и
nowiki-блоки, базовое inline-форматирование, внутренние/внешние ссылки и media.
Три неизменённые штатные страницы актуального релиза DokuWiki
`2025-05-14b "Librarian"` исключаются только при совпадении пути и SHA-256;
изменённые пользовательские версии сохраняются. Неизвестный plugin-синтаксис,
interwiki и неразрешённые ссылки остаются видимыми и сопровождаются
предупреждением.

Obsidian импортирует Markdown и обычные файлы vault, но молча исключает
`.obsidian`. Wiki links, aliases, headings, block references и embeds
переписываются в относительные Markdown-ссылки с учётом итогового плана;
неоднозначные и отсутствующие цели остаются без разрушительного угадывания.
Вложенные архивы считаются обычными файлами.

Каждый запуск создаёт отдельную папку
`Импортировано/<DokuWiki|Obsidian> — YYYY-MM-DD HH-MM-SS`; при совпадении имени
добавляется `(2)`, `(3)` и далее. Плагин показывает одно общее предупреждение,
что импорт может содержать логины, пароли или другие приватные данные. Такие
страницы обрабатываются как обычные: плагин не ищет, не перемещает в Secrets и
не удаляет их.

Текущий статус: реализован как официальный settings-плагин. Поддерживаются
только актуальные структуры DokuWiki и Obsidian; старые форматы отдельно не
эмулируются.

## 15. `verstak.platform-test`

Назначение:

- тестовый плагин для отладки runtime;
- диагностические панели для проверки API;
- не для конечных пользователей.

Текущий статус: используется только при разработке.

# Platform Development Strategy

## 1. Цель

Verstak развивается как local-first платформа с динамическими плагинами:

- local-first vault;
- дела как центр контекста;
- человекочитаемые файлы;
- заметки, файлы, журнал, активность, браузерные материалы вокруг дела;
- синхронизация и расширение как отдельные части, а не ядро смысла.

## 2. Нельзя делать

- Нельзя добавлять новые функции в монолитный `App.svelte`.
- Нельзя делать official plugins скрытыми compile-time modules.
- Нельзя связывать плагины по именам, если нужна capability.
- Нельзя делать notes/files/editor обязательными частями core.
- Нельзя менять vault layout без явного плана изменения формата.
- Нельзя хранить секреты как обычные заметки или plain text.
- Нельзя молча менять title/filename note при конфликте.

## 3. Этап 1 - Platform Skeleton

Сделано в `verstak-desktop`:

- plugin manifest schema;
- plugin discovery from plugin directories;
- enable/disable state;
- plugin manager UI;
- plugin status model;
- capability registry;
- contribution registry;
- settings registry;
- basic event bus;
- diagnostics panel.

## 4. Этап 2 - Frontend Plugin Host

Сделано:

- загрузку frontend bundle;
- `VerstakPluginAPI`;
- registration of views/settings/commands;
- plugin UI error boundary;
- settings panel invocation from Plugin Manager.

## 5. Этап 3 - Backend Sidecar Host

Отложено до отдельного milestone.

План:

- sidecar launch protocol;
- local RPC;
- permission-scoped API;
- sidecar shutdown/restart;
- logs/diagnostics.

## 6. Этап 4 - Official Plugin Development

Развиваются по одному, через общий plugin runtime:

1. `verstak.default-editor` ✅
2. `verstak.files` ✅
3. `verstak.notes` ✅
4. `verstak.file-preview` ✅ (базовый)
5. `verstak.activity` ✅
6. `verstak.journal` ✅ (базовый)
7. `verstak.browser-inbox` ✅
8. `verstak.search` ✅ (базовый)
9. `verstak.secrets` ✅
10. `verstak.todo` ✅
11. `verstak.trash` ✅
12. `verstak.sync` ✅
13. `verstak.templates` ✅

После каждого изменения:

- проверить build;
- проверить запуск;
- проверить Plugin Manager;
- проверить enable/disable;
- проверить degraded mode при отключении optional plugin;
- проверить, что vault остается читаемым;
- проверить, что UI contributions исчезают при disable.

## 7. Этап 5 - Repository Split

Выполнено:

- core и shell в `verstak-desktop`;
- official plugins в `verstak-official-plugins`;
- sync server в `verstak-sync-server`;
- browser extension в `verstak-browser-extension`;
- SDK в `verstak-sdk`;
- документация в `verstak-docs`.

## 8. Definition Of Done (текущий статус)

Платформенный переход состоялся:

- [x] core запускается без official plugins;
- [x] official plugins лежат вне core modules;
- [x] notes/files/editor/preview/activity работают как плагины;
- [x] Plugin Manager умеет включать/выключать плагины;
- [x] плагин может иметь свое settings окно;
- [x] capability registry управляет видимостью actions;
- [x] отсутствие optional capability не считается ошибкой;
- [x] vault layout стабилен и читаем;
- [x] документация соответствует реализации (в процессе).

Оставшиеся крупные задачи:

- [ ] Sidecar/sandbox изоляция;
- [ ] Production-grade packaging и автообновление;
- [ ] Operation-log retention (sync server);
- [ ] Синхронизация Secrets, plugin settings, Todo, Journal, Activity, Browser Inbox;
- [ ] UX-полировка (Today flow, mobile layout, search в workspace header).

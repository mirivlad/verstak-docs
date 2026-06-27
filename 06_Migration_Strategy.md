# Platform Development Strategy

## 1. Цель

Verstak v2 разрабатывается как отдельное приложение и платформа. Цель -
собрать рабочий local-first vault вокруг дел без временных мостов к первой
версии:

- local-first vault;
- дела как центр контекста;
- человекочитаемые файлы;
- заметки, файлы, журнал, активность, браузерные материалы вокруг дела;
- синхронизация и расширение как отдельные части, а не ядро смысла.

Это не миграция v1 -> v2 и не перенос старого монолита частями. Это развитие
самостоятельной платформенной модели.

## 2. Нельзя делать

- Нельзя добавлять новые функции в монолитный `App.svelte`.
- Нельзя делать official plugins скрытыми compile-time modules.
- Нельзя связывать плагины по именам, если нужна capability.
- Нельзя делать notes/files/editor обязательными частями core.
- Нельзя добавлять временные compatibility bridges к первой версии.
- Нельзя менять v2 vault layout без явного плана изменения формата.
- Нельзя хранить секреты как обычные заметки или plain text.
- Нельзя молча менять title/filename note при конфликте.

## 3. Этап 1 - Platform Skeleton

Сделать в `verstak-desktop`:

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

Проверки:

- приложение запускается без плагинов;
- приложение показывает пустой Plugin Manager;
- тестовый плагин появляется в списке;
- enable/disable работает;
- failed plugin не роняет приложение.

## 4. Этап 2 - Frontend Plugin Host

Сделать:

- загрузку frontend bundle;
- `VerstakPluginAPI`;
- registration of views/settings/commands;
- plugin UI error boundary;
- settings panel invocation from Plugin Manager.

Проверки:

- тестовый плагин регистрирует view;
- тестовый плагин регистрирует settings panel;
- выключение плагина убирает view/settings;
- ошибка в plugin UI не роняет shell.

## 5. Этап 3 - Backend Sidecar Host

Сделать:

- sidecar launch protocol;
- local RPC;
- permission-scoped API;
- sidecar shutdown/restart;
- logs/diagnostics.

Проверки:

- sidecar отвечает health check;
- sidecar не получает API без permissions;
- падение sidecar переводит плагин в failed;
- disable останавливает sidecar.

## 6. Этап 4 - Official Plugin Development

Развивать official plugins по одному, через общий plugin runtime:

1. `official.markdown-editor`;
2. `official.files`;
3. `official.notes`;
4. `official.file-preview`;
5. `official.activity`;
6. `official.browser-inbox`.

После каждого выноса:

- проверить build;
- проверить запуск;
- проверить Plugin Manager;
- проверить enable/disable;
- проверить degraded mode при отключении optional plugin;
- проверить, что v2 vault остается читаемым и не получает скрытых
  plugin-specific truth-слоев для пользовательских документов;
- проверить, что UI contributions исчезают при disable.

## 7. Этап 5 - Repository Split

Когда plugin runtime работает:

- оставить core и shell в `verstak-desktop`;
- вынести official plugins в `verstak-official-plugins`;
- вынести sync server в `verstak-sync-server`;
- вынести browser extension в `verstak-browser-extension`;
- выделить `verstak-sdk` после стабилизации API.

Не начинать с физического split repo, пока runtime не умеет грузить плагины локально.

## 8. Definition Of Done

Платформенный переход можно считать состоявшимся, когда:

- core запускается без official plugins;
- official plugins лежат вне core modules;
- notes/files/editor/preview/activity работают как плагины;
- Plugin Manager умеет включать/выключать плагины;
- плагин может иметь свое settings окно;
- capability registry управляет видимостью actions;
- отсутствие optional capability не считается ошибкой;
- v2 vault layout остается стабильным и читаемым без compatibility bridges к v1;
- документация соответствует реализации.

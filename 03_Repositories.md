# Verstak Repositories

## 1. Организация

Для GitHub/Gitea лучше использовать organization `verstak` или аналогичную общую группу. Внутри нее живут отдельные репозитории одной продуктовой идеи.

Project board можно вести на уровне organization: roadmap, issues, milestones, cross-repo tasks.

## 2. Минимальный набор репозиториев

### `verstak-desktop`

Основное desktop-приложение.

Содержит:

- Core Platform;
- UI Shell;
- plugin loader;
- capability registry;
- settings window;
- plugin manager UI;
- vault API;
- storage API;
- event bus;
- sync client boundary;
- dev harness для локальных плагинов.

Не содержит:

- notes как обязательный модуль;
- file manager как обязательный модуль;
- markdown editor как обязательный модуль;
- browser extension код;
- sync server код.

### `verstak-official-plugins`

Монорепозиторий официальных плагинов.

Содержит:

```text
plugins/
  files/
  notes/
  markdown-editor/
  file-preview/
  activity/
  journal/
  browser-inbox/
  search/
  secrets/
  templates/
packages/
  plugin-sdk/
  shared-ui/
  test-harness/
```

Официальные плагины должны устанавливаться и загружаться так же, как сторонние. Нельзя делать для них скрытый privileged path, кроме явно описанных platform permissions.

### `verstak-sdk`

Общие контракты для разработки плагинов.

Содержит:

- manifest schema;
- TypeScript SDK;
- RPC protocol definitions;
- capability contracts;
- event schemas;
- test helpers;
- plugin packaging tools;
- examples.

На раннем этапе SDK может жить в `verstak-official-plugins/packages/plugin-sdk`, но должен быть выделен в отдельный репозиторий, когда API начнет стабилизироваться.

### `verstak-sync-server`

Отдельный сервер синхронизации.

Содержит:

- HTTP API;
- auth/pairing;
- device registry;
- vault operation log;
- blob upload/download;
- conflict handling;
- retention/deleted file policy;
- server migrations;
- deployment docs.

Sync server не должен импортировать desktop UI или official plugins.

### `verstak-browser-extension`

Расширение браузера.

Содержит:

- Firefox/Chromium extension;
- local pairing with Verstak;
- page capture;
- selected text capture;
- link sending;
- pending queue if desktop is offline;
- domain bindings support;
- protocol docs for browser inbox plugin.

Расширение не должно напрямую знать внутреннюю структуру notes/files/activity. Оно отправляет события в local receiver, а обработка идет через плагин `official.browser-inbox`.

## 3. Репозитории позже

### `verstak-plugin-registry`

Каталог доступных плагинов:

- official plugin index;
- third-party plugin metadata;
- signatures/checksums;
- compatibility matrix;
- install URLs.

Не нужен в первый этап, если плагины ставятся вручную из локальной папки или из `verstak-official-plugins`.

### `verstak-docs`

Публичная документация:

- user guide;
- developer guide;
- plugin authoring guide;
- sync setup;
- security model;
- migration guides.

Может быть отдельным репозиторием позже. Сейчас допустимо держать архитектурные документы рядом с `verstak-desktop`.

## 4. Что не дробить слишком рано

Не стоит сразу создавать отдельный репозиторий на каждый официальный плагин. Это увеличит накладные расходы и усложнит синхронные изменения SDK/API.

Лучше:

```text
verstak-official-plugins - один repo для официальных плагинов
```

А отдельные repo оставить для сторонних плагинов или крупных независимых модулей.

## 5. Версионирование

Версии должны существовать на трех уровнях:

- app version: версия `verstak-desktop`;
- platform apiVersion: версия API плагинов;
- plugin version: версия конкретного плагина.

Плагин объявляет:

```json
{
  "version": "0.1.0",
  "apiVersion": "1"
}
```

Core может загрузить плагин только при совместимости `apiVersion`.

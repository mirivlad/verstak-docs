# Verstak Repositories

## 1. Организация

Проект состоит из шести репозиториев под [github.com/mirivlad](https://github.com/mirivlad):

- `verstak` — основное desktop-приложение (Core Platform + UI Shell)
- `verstak-official-plugins` — монорепозиторий официальных плагинов
- `verstak-sdk` — TypeScript SDK, схемы и контракты плагинов
- `verstak-browser-extension` — расширение браузера
- `verstak-sync-server` — сервер синхронизации
- `verstak-docs` — платформенная и архитектурная документация

Локально репозитории клонируются как sibling-директории:

```text
verstak2/
├── verstak-desktop/
├── verstak-official-plugins/
├── verstak-sdk/
├── verstak-browser-extension/
├── verstak-sync-server/
└── verstak-docs/
```

## 2. Назначение репозиториев

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
- workspace manager;
- file watcher;
- notifications;
- browser receiver (local HTTP endpoint);
- secret store (AES-GCM).

Не содержит:

- notes как обязательный модуль;
- file manager как обязательный модуль;
- markdown editor как обязательный модуль;
- browser extension код;
- sync server код.

### `verstak-official-plugins`

Монорепозиторий официальных плагинов:

```
plugins/
  platform-test/      — тестовый плагин для проверки runtime
  files/              — файловый менеджер
  notes/              — заметки
  default-editor/     — редактор текста/markdown
  file-preview/       — предпросмотр изображений
  activity/           — активность
  journal/            — журнал работ
  browser-inbox/      — браузерный inbox
  search/             — поиск
  secrets/            — хранилище секретов
  todo/               — задачи
  trash/              — корзина
  sync/               — синхронизация
```

Все плагины используют префикс `verstak.*` в id. Официальные плагины загружаются через тот же plugin runtime, что и сторонние.

### `verstak-sdk`

Общие контракты для разработки плагинов:

- JSON Schema для manifest, capabilities, contributions, permissions, sync;
- TypeScript типы для plugin API;
- тестовые утилиты.

### `verstak-sync-server`

Отдельный сервер синхронизации:

- HTTP API;
- auth/pairing;
- device registry;
- vault operation log;
- blob upload/download;
- embedded web console;
- deployment docs.

### `verstak-browser-extension`

Расширение браузера (Firefox/Chromium):

- local pairing with Verstak;
- page capture, selection, link, file;
- pending queue;
- domain bindings;
- passive domain activity (opt-in).

### `verstak-docs`

Платформенная и архитектурная документация:

- product vision;
- platform architecture;
- plugin system overview;
- official plugins reference;
- development strategy;
- implementation roadmap.

## 3. Версионирование

Версии существуют на трёх уровнях:

- app version: версия `verstak-desktop`;
- platform apiVersion: версия API плагинов;
- plugin version: версия конкретного плагина.

Плагин объявляет:

```json
{
  "version": "0.1.0",
  "apiVersion": "0.1.0"
}
```

Core может загрузить плагин только при совместимости `apiVersion`.
Совместимые компоненты следует собирать из одной релизной линии.

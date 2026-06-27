# Verstak Platform Architecture

## 1. Общая схема

```text
                 +----------------------+
                 |      UI Shell        |
                 |  windows, layout,    |
                 |  command palette,    |
                 |  settings, toasts    |
                 +----------+-----------+
                            |
                 +----------v-----------+
                 |    Core Platform     |
                 | plugin manager,      |
                 | capabilities,        |
                 | permissions, events  |
                 +----------+-----------+
                            |
        +-------------------+-------------------+
        |                   |                   |
+-------v--------+  +-------v--------+  +-------v--------+
| Local Vault    |  | Storage API    |  | Sync Boundary  |
| files, notes,  |  | SQLite, index, |  | client adapter |
| assets, trash  |  | migrations     |  | not core truth |
+-------+--------+  +-------+--------+  +-------+--------+
        |                   |                   |
        +-------------------+-------------------+
                            |
                 +----------v-----------+
                 |  Dynamic Plugins     |
                 | official and third   |
                 | party packages       |
                 +----------------------+
```

## 2. Core Platform

Core Platform - минимальное ядро приложения. Оно не содержит бизнес-функции пользователя. Его задача - дать среду, в которую плагины безопасно подключают рабочие инструменты.

Core отвечает за:

- запуск приложения;
- открытие и проверку vault;
- загрузку и выгрузку плагинов;
- enable/disable состояние плагинов;
- capability registry;
- contribution points;
- settings registry;
- permissions;
- event bus;
- storage API;
- vault file API;
- command registry;
- diagnostics;
- sync boundary.

Core не должен импортировать конкретные плагины как обязательные модули.

## 3. UI Shell

UI Shell - общий интерфейс платформы:

- главное окно;
- навигация;
- вкладки и панели;
- command palette;
- global search entry point;
- settings window;
- plugin manager window;
- dialogs/toasts;
- error boundary для plugin UI.

UI Shell не знает, что такое notes editor или file preview как конкретная реализация. Он знает contribution points:

- sidebar items;
- main views;
- case tabs;
- file actions;
- note actions;
- context menu entries;
- settings panels;
- command palette commands;
- status bar items;
- activity cards;
- search providers.

## 4. Vault

Vault остается пользовательским рабочим пространством. Он должен быть максимально понятным снаружи.

Пример:

```text
VerstakVault/
  .verstak/
    db.sqlite
    config.json
    plugins/
    plugin-state/
    cache/
    trash/
  Clients/
    Romashka/
      Notes/
        project-plan.md
      Files/
      Screenshots/
  Projects/
```

Правила:

- пользовательские документы не прячутся в непрозрачные blob-таблицы без необходимости;
- SQLite хранит индексы, связи, историю, состояние UI, plugin metadata;
- файловая структура должна оставаться пригодной для ручного восстановления;
- имена заметок и файлов остаются человекочитаемыми;
- sync не является единственным способом доступа к данным.

## 5. Plugin Runtime

Плагины загружаются динамически из каталогов. Официальные плагины используют тот же механизм, что и сторонние.

Папки плагинов:

```text
VerstakVault/.verstak/plugins/
  official.files/
  official.notes/
  official.markdown-editor/

~/.config/verstak/plugins/
  user.local-plugin/
```

Порядок загрузки:

1. Найти plugin manifests.
2. Проверить schemaVersion и apiVersion.
3. Проверить enabled/disabled state.
4. Проверить обязательные capabilities.
5. Запросить permissions.
6. Запустить backend sidecar, если нужен.
7. Загрузить frontend bundle, если нужен.
8. Принять регистрации capabilities и contributions.
9. Перевести плагин в состояние loaded/degraded/failed/incompatible.

## 6. Backend Model

Не использовать Go `plugin` как основной механизм. Он плохо подходит для кроссплатформенного desktop-приложения из-за ABI, версий компилятора и сборки под разные ОС.

Предпочтительная модель:

- плагин может быть pure frontend;
- плагин может быть pure manifest/data;
- плагин может иметь backend sidecar;
- sidecar общается с core через локальный RPC;
- core выдает sidecar только разрешенные API;
- прямой произвольный доступ к vault и OS запрещен по умолчанию.

Sidecar может быть написан на Go, Rust, Python или другом языке, если он соблюдает протокол.

## 7. Frontend Model

Плагин поставляет frontend bundle:

```text
frontend/
  index.js
  style.css
```

Frontend bundle не должен напрямую обращаться к Wails backend methods как к глобальному хаосу. Он работает через `VerstakPluginAPI`, который предоставляет:

- registerView;
- registerSettingsPanel;
- registerCommand;
- registerFileAction;
- callBackend;
- readSettings/writeSettings;
- subscribe/publish events;
- requestCapability.

## 8. Capability Registry

Плагины связываются не по имени друг друга, а через capabilities.

Пример:

```text
editor.text
editor.text.markdown
viewer.file
viewer.image
preview.markdown
workspace.files
workspace.notes
capture.browser
activity.provider
secret-store
search.provider
```

Файловый плагин не зависит от `official.markdown-editor`. Он проверяет, есть ли capability `editor.text.markdown`. Если есть - показывает действие "Редактировать". Если нет - действие не появляется.

## 9. Plugin Manager UI

Core обязан иметь окно управления плагинами с первого платформенного этапа.

Функции:

- список установленных плагинов;
- enable/disable;
- status: loaded, disabled, failed, incompatible, degraded;
- version и apiVersion;
- source: official, local, third-party;
- capabilities provided;
- required/optional capabilities;
- permissions;
- кнопка "Settings", если плагин предоставляет settings panels;
- diagnostics/error log.

Выключение плагина не удаляет пользовательские данные.

## 10. Settings Registry

Настройки плагинов не должны быть произвольными экранами, спрятанными в разных местах.

Плагин регистрирует settings panels:

```json
{
  "contributes": {
    "settingsPanels": [
      {
        "id": "official.notes.general",
        "title": "Notes",
        "component": "settings.general"
      }
    ]
  }
}
```

Core показывает кнопку настроек у выбранного плагина и открывает соответствующую панель/окно.

## 11. Event Bus

Event bus связывает плагины без прямых импортов.

Примеры событий:

- `vault.opened`;
- `case.selected`;
- `file.added`;
- `file.changed`;
- `note.saved`;
- `activity.recorded`;
- `browser.capture.received`;
- `plugin.enabled`;
- `plugin.disabled`.

События должны иметь стабильные схемы. Плагин не должен полагаться на приватные поля другого плагина.

## 12. Sync Boundary

Sync server и browser extension выносятся в отдельные репозитории, но должны использовать общие protocol contracts.

Sync не должен знать о внутренних UI-плагинах. Он синхронизирует:

- vault metadata;
- files/blobs;
- plugin state where allowed;
- plugin data через зарегистрированные storage namespaces.

Плагины должны явно указывать, какие данные можно синхронизировать, а какие локальны только на устройстве.

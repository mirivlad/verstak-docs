# Verstak Plugin System

> Подробный reference по реализации: [Plugin Runtime](../verstak-desktop/docs/PLUGIN_RUNTIME.md).

## 1. Цель

Плагины превращают Верстак из монолитного приложения в платформу. Любая пользовательская функция должна быть реализуема как плагин:

- заметки;
- файловый менеджер;
- редактор;
- просмотрщик;
- журнал;
- активность;
- браузерный inbox;
- поиск;
- секреты;
- импорт;
- шаблоны дел.

## 2. Структура плагина

```text
verstak.notes/
  plugin.json
  frontend/
    dist/
      index.js
      style.css
  backend/
    plugin-linux-amd64
    plugin-windows-amd64.exe
  migrations/
    001_init.sql
  assets/
  README.md
```

Не каждый плагин обязан иметь frontend/backend/migrations. Manifest обязателен.

## 3. Manifest

Manifest — файл `plugin.json` в корне директории плагина.

```json
{
  "schemaVersion": 1,
  "id": "verstak.notes",
  "name": "Notes",
  "version": "0.1.0",
  "apiVersion": "0.1.0",
  "description": "Markdown notes inside Verstak workspaces.",
  "source": "official",
  "localization": {
    "defaultLocale": "en",
    "locales": {
      "en": "locales/en.json",
      "ru": "locales/ru.json"
    }
  },
  "provides": [
    "workspace.notes",
    "entity.note"
  ],
  "requires": [
    "vault.files"
  ],
  "optionalRequires": [
    "editor.text.markdown",
    "preview.markdown",
    "search.provider"
  ],
  "permissions": [
    "files.read",
    "files.write",
    "storage.namespace",
    "ui.register",
    "events.publish",
    "events.subscribe",
    "workbench.open"
  ],
  "frontend": {
    "entry": "frontend/dist/index.js",
    "style": "frontend/dist/style.css"
  },
  "backend": {
    "type": "sidecar",
    "entry": {
      "linux-amd64": "backend/plugin-linux-amd64",
      "windows-amd64": "backend/plugin-windows-amd64.exe"
    }
  },
  "contributes": {
    "views": [],
    "commands": [],
    "settingsPanels": []
  }
}
```

### 3.1. Локализация

Локализуемый плагин объявляет собственные JSON-каталоги в `localization`.
Пути должны быть относительными, использовать `/` и оставаться внутри каталога
плагина. Все значения каталога — строки. Литеральные английские значения в
manifest остаются fallback, а переводы metadata используют стабильные ключи:

```text
manifest.name
manifest.description
contributions.views.<id>.title
contributions.commands.<id>.title
contributions.statusBarItems.<id>.label
```

Внутренний UI плагина получает текущий язык только через публичный API:

```js
const locale = api.i18n.getLocale();
const title = api.i18n.t('ui.title', undefined, 'Notes');
const unsubscribe = api.i18n.onDidChangeLocale(nextLocale => {
  // Обновить текст без перемонтирования компонента и потери состояния.
});
```

Desktop поддерживает `system`, `en` и `ru`. В режиме `system` локали `ru-*`
выбирают русский язык, остальные — английский. Плагин отвечает за свои
переводы; desktop core не содержит тексты официальных плагинов.

## 4. Capabilities Instead Of Plugin Names

Плагины не должны требовать конкретный плагин, если им нужна способность.

Плохо:

```json
{
  "requires": ["verstak.default-editor"]
}
```

Хорошо:

```json
{
  "optionalRequires": ["editor.text.markdown"]
}
```

Так можно заменить редактор, поставить два редактора или временно выключить предпросмотр без поломки файлового плагина.

## 5. Required And Optional Capabilities

`requires` - без этих capabilities плагин не может работать.

`optionalRequires` - без них плагин работает в degraded mode.

Пример:

```text
verstak.notes
  requires:
    verstak/core/files/v1
  optionalRequires:
    editor.text.markdown
    search.provider
```

Если нет `preview.markdown`, заметки работают, но кнопка предпросмотра не появляется.

## 6. Plugin States

Core должен различать состояния:

- `discovered` - manifest найден;
- `disabled` - пользователь выключил;
- `loading` - идет загрузка;
- `loaded` - успешно загружен;
- `degraded` - работает без optional capabilities;
- `failed` - ошибка загрузки/запуска;
- `incompatible` - неподдерживаемый apiVersion/schemaVersion;
- `missing-required-capability` - не хватает обязательной capability.

Состояние видно в Plugin Manager UI.

## 7. Lifecycle

```text
discover
validate manifest
check compatibility
check enabled state
resolve required capabilities
request permissions
run migrations
start backend sidecar
load frontend bundle
register capabilities
register contributions
activate
deactivate
shutdown
```

Lifecycle hooks:

- `onInstall`;
- `onEnable`;
- `onVaultOpen`;
- `onActivate`;
- `onDeactivate`;
- `onDisable`;
- `onUninstall`;
- `onShutdown`.

## 8. Contribution Points

Плагин может регистрировать:

- sidebar item;
- main view;
- case tab;
- file action;
- note action;
- context menu item;
- command palette command;
- settings panel;
- search provider;
- activity provider;
- importer;
- exporter;
- vault scanner;
- protocol receiver.

Contribution должен быть декларативным, где возможно. Runtime callbacks нужны только для поведения.

## 9. Plugin Settings

Окно настроек плагинов - обязательная часть core.

Плагин объявляет settings panels:

```json
{
  "contributes": {
    "settingsPanels": [
      {
        "id": "verstak.default-editor.general",
        "title": "Default Editor",
        "component": "settings.general"
      }
    ]
  }
}
```

Plugin Manager показывает кнопку настроек только если у плагина есть settings panels.

Настройки хранятся в namespace плагина:

```text
plugin_settings/<plugin_id>/
```

Плагин не должен читать/писать настройки другого плагина без разрешения.

## 10. Enable/Disable Rules

Выключение плагина:

- убирает его UI contributions;
- убирает commands/actions;
- отзывает provided capabilities;
- останавливает sidecar;
- сохраняет данные плагина;
- не удаляет пользовательские файлы;
- публикует событие `plugin.disabled`.

Включение плагина:

- повторно проверяет совместимость;
- выполняет pending migrations;
- регистрирует contributions;
- публикует событие `plugin.enabled`.

Если другой плагин использовал optional capability выключенного плагина, он переходит в degraded mode. Если required capability исчезла, зависимый плагин должен быть деактивирован или переведен в failed/missing-required state.

## 11. Permissions

Минимальный набор permissions:

```text
vault.read
vault.write
vault.watch
storage.namespace
storage.migrations
events.publish
events.subscribe
ui.register
commands.register
imports.readExternal
imports.apply
network.local
network.remote
process.spawn
secrets.read
secrets.write
sync.participate
```

Опасные разрешения должны быть видны пользователю до включения плагина:

- `network.remote`;
- `process.spawn`;
- `secrets.read`;
- `vault.write`;
- `imports.readExternal`;
- `imports.apply`;
- `sync.participate`.

### 11.1. Generic Import API

Core capability `verstak/core/import/v1` exposes a plugin-scoped `api.imports`
contract. The host, not the plugin, opens native selectors and owns access to
the selected directory or archive:

```js
const source = await api.imports.selectDirectory(); // or selectArchive()
const page = await api.imports.listEntries(source.sourceHandle, cursor);
const text = await api.imports.readText(source.sourceHandle, entryId);
const unsubscribe = api.imports.onProgress(source.sourceHandle, listener);
const result = await api.imports.applyPlan(source.sourceHandle, reviewedPlan);
await api.imports.cancel(source.sourceHandle);
await api.imports.closeSource(source.sourceHandle);
```

`imports.readExternal` is required to select, enumerate and read a source;
`imports.apply` is additionally required to publish a reviewed plan. Handles
are opaque, owned by the plugin that opened them, expire after 30 minutes of
inactivity, and are closed when the API instance is disposed or the plugin is
disabled. Plugins receive normalized inventory records and bounded UTF-8 text,
not arbitrary filesystem paths.

Supported archives are `.zip`, `.tar`, `.tar.gz` and `.tgz`. A source is
limited to 250,000 entries, 20 GiB unpacked total, 2 GiB per entry, 16 MiB per
text entry and a 1000:1 expansion ratio. Inventory pages contain up to 500
entries. Links and special archive entries, traversal, duplicate normalized
paths and source changes after analysis are rejected.

`applyPlan()` accepts only a validated plan tied to the source handle and
fingerprint. Core stages all folders, deals, Markdown notes, files and workspace
metadata under `.verstak/import-staging`, checks free disk space, then publishes
the run atomically under `Импортировано`. Startup recovery removes or rolls back
an interrupted transaction using its private journal. Cancellation is allowed
during validation and staging, but not after publication begins; progress
reports `validating`, `staging`, `publishing` and `refreshing` phases.

## 12. Data Ownership

Каждый плагин имеет namespace:

```text
plugin_data/<plugin_id>/
plugin_settings/<plugin_id>/
plugin_cache/<plugin_id>/
```

Пользовательские данные должны отделяться от cache.

Uninstall не должен автоматически удалять пользовательские данные без явного подтверждения.

## 13. Packaging

Плагин распространяется как директория внутри `plugins/` или как архив:

```text
verstak.notes-0.1.0.tar.gz
```

Пакет содержит:

- `plugin.json`;
- frontend bundle (`frontend/dist/`);
- backend binaries if any;
- migrations;
- README;
- checksums/signature later.

Подробнее о сборке: [PACKAGING.md](../verstak-official-plugins/docs/PACKAGING.md).

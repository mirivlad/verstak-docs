# Milestone: Platform Runtime 1

Фиксирует текущее состояние plugin runtime в Milestone 1.

## Что уже работает

- **Plugin Discovery** — сканирование директорий, чтение plugin.json, валидация манифеста.
- **Core Capabilities** — 5 capabilities регистрируются в `main.go` ДО plugin discovery.
- **Plugin Lifecycle** — полный цикл: discovered → loaded / degraded / missing-required-capability / failed.
- **Dev Install Flow** — `./scripts/build.sh` + `./scripts/install-dev-plugins.sh`.
- **Smoke Platform** — `./scripts/smoke-platform.sh` проверяет discovery, capabilities, lifecycle без GUI.
- **Wails v2 + Svelte 4** — core запускается, Plugin Manager UI работает.
- **platform-test plugin** — собирается, устанавливается, проходит lifecycle, регистрирует contributions.

## Репозитории

| Репозиторий | За что отвечает |
|---|---|
| `verstak-desktop` | Core platform: plugin runtime, capability/contribution/permission registries, event bus, Wails shell, Plugin Manager UI |
| `verstak-official-plugins` | Монорепо официальных плагинов (platform-test и будущие) |
| `verstak-docs` | Документация платформы (этот репозиторий) |
| `verstak-sdk` | Manifest schema + TypeScript SDK |
| `verstak-sync-server` | Сервер синхронизации |
| `verstak-browser-extension` | Расширение Firefox |

## Core Capabilities (зарегистрированы)

Следующие capabilities регистрируются в `main.go` до plugin discovery, чтобы плагины могли разрешить `requires` при загрузке:

| Capability | Описание |
|---|---|
| `verstak/core/plugin-manager/v1` | Управление плагинами: discovery, enable/disable, reload |
| `verstak/core/capability-registry/v1` | Реестр возможностей: регистрация, запрос, проверка зависимостей |
| `verstak/core/contribution-registry/v1` | Реестр контрибуций: views, commands, sidebar items, actions и т.д. |
| `verstak/core/permissions/v1` | Реестр разрешений: проверка dangerous, запрос пользователю |
| `verstak/core/events/v1` | In-process event bus: publish/subscribe |

### Capabilities НЕ зарегистрированы (намеренно)

| Capability | Почему отсутствует |
|---|---|
| `verstak/core/vault/v1` | Реализация vault api (`internal/core/vault/api.go`) ещё не создана |
| `verstak/core/sync/v1` | Реализация sync boundary (`internal/core/sync/boundary.go`) ещё не создана |

Плагины, объявляющие эти capabilities в `optionalRequires`, переходят в статус `degraded`, но продолжают работать. Плагины с `requires` получат `missing-required-capability`.

## DEGRADED: что означает

Плагин получает статус `degraded`, когда:

1. Все `requires` capabilities разрешены (есть в registry).
2. Хотя бы одна из `optionalRequires` capabilities отсутствует.

В этом состоянии:
- Плагин загружается и регистрирует свои `provides` capabilities.
- Contributions (views, commands, sidebar items) попадают в registry.
- Plugin Manager UI показывает статус `degraded` с указанием отсутствующих optional capabilities.
- UI-функции, зависящие от отсутствующих capabilities, должны скрываться или gracefully degrade.

## Команды для полной проверки

```bash
# 1. Собрать официальные плагины (соберёт frontend, backend, упакует dist/)
cd ~/git/verstak2/verstak-official-plugins
./scripts/build.sh

# 2. Установить platform-test как dev plugin в verstak-desktop
cd ~/git/verstak2/verstak-desktop
./scripts/install-dev-plugins.sh

# 3. Запустить smoke-проверку (headless, без GUI)
./scripts/smoke-platform.sh

# 4. Запустить приложение (откроет Wails GUI)
go run -mod=mod .
```

## Проверка через Plugin Manager UI

1. Запустить приложение: `go run -mod=mod .`
2. Открыть Plugin Manager.
3. Убедиться, что `verstak.platform-test` отображается со статусом `degraded`.
4. Убедиться, что указаны отсутствующие optional capabilities (`verstak/core/vault/v1`, `verstak/core/sync/v1`).
5. Contributions (view, commands, sidebar item) должны быть видны.

## Файлы реализации

| Файл | Назначение |
|---|---|
| `verstak-desktop/main.go` | Инициализация core, регистрация capabilities, plugin lifecycle, Wails run |
| `verstak-desktop/internal/api/app.go` | Wails-bound API, ReloadPlugins, GetPlugins, GetCapabilities |
| `verstak-desktop/internal/core/plugin/plugin.go` | Manifest struct, ValidateManifest, DiscoverPlugins, Status constants |
| `verstak-desktop/internal/core/capability/registry.go` | CapabilityRegistry: Register, CheckRequired, List |
| `verstak-desktop/internal/core/contribution/registry.go` | ContributionRegistry: views, commands, sidebar items и т.д. |
| `verstak-desktop/internal/core/permissions/registry.go` | PermissionsRegistry: defaults, IsDangerous |
| `verstak-desktop/internal/core/events/bus.go` | EventBus: Subscribe, Publish |
| `verstak-desktop/cmd/smoke-platform/main.go` | Headless smoke test |
| `verstak-official-plugins/scripts/build.sh` | Build + package всех плагинов |
| `verstak-desktop/scripts/install-dev-plugins.sh` | Копирование dist/ в ./plugins/ |
| `verstak-desktop/scripts/smoke-platform.sh` | Полная smoke-проверка |

# Milestone: Platform Runtime 2 — Vault Core Capability

Фиксирует состояние plugin runtime после добавления vault layer как core capability.

## Что реализовано

- **Vault Layer** — полноценный vault service (`internal/core/vault/vault.go`) с созданием, открытием, закрытием и валидацией.
- **Vault Capability** — `verstak/core/vault/v1` регистрируется в `main.go` и доступен плагинам через capability registry.
- **Vault Events** — `vault.created`, `vault.opened`, `vault.closed` публикуются в event bus.
- **Vault Tests** — `internal/core/vault/vault_test.go` покрывает layout creation, open/close cycle, corrupt JSON, path traversal, plugin namespace paths, status transitions, event publishing.
- **platform-test plugin** — статус обновлён: был `degraded` из-за отсутствия vault, теперь `degraded` только из-за отсутствия `verstak/core/sync/v1`.

## Vault Layout

```
<base>/
  VerstakVault/           ← vault root (создаётся CreateVault)
    .verstak/
      vault.json          ← VaultMeta: schemaVersion=1, vaultId (UUID), createdAt, updatedAt, app="verstak"
      plugin-data/        ← per-plugin data namespaces
        <plugin-id>/
      plugin-settings/    ← per-plugin settings namespaces
        <plugin-id>/
      plugin-cache/       ← per-plugin cache namespaces
        <plugin-id>/
      trash/              ← soft-deleted items
      logs/               ← vault-scoped logs
```

`EnsureVaultLayout()` создаёт `.verstak/` и все стандартные поддиректории. Идемпотентен — безопасно вызывать повторно.

## Vault API

| Метод | Описание |
|---|---|
| `NewVault(bus)` | Создаёт Vault instance. Начальный статус: `not-created`. |
| `CreateVault(path)` | Создаёт `VerstakVault/` на указанном пути. Генерирует `vault.json` с UUID. Публикует `vault.created`. Статус → `open`. |
| `OpenVault(path)` | Открывает существующий vault. Валидирует `vault.json` (schemaVersion, vaultId). Публикует `vault.opened`. Статус → `open`. |
| `CloseVault()` | Закрывает vault. Сбрасывает path и meta. Публикует `vault.closed`. Статус → `closed`. |
| `GetVaultStatus()` | Текущий статус: `not-created`, `closed`, `open`, `error`. |
| `GetVaultPath()` | Путь к vault root. |
| `GetVaultMeta()` | Указатель на `VaultMeta` (vaultId, timestamps, app). |
| `ResolveSafePath(rel)` | Резолвит относительный путь внутри vault. Блокирует `../` traversal. Требует `open` vault. |
| `GetPluginDataPath(id)` | Возвращает (и создаёт) `.verstak/plugin-data/<id>/`. |
| `GetPluginSettingsPath(id)` | Возвращает (и создаёт) `.verstak/plugin-settings/<id>/`. |
| `GetPluginCachePath(id)` | Возвращает (и создаёт) `.verstak/plugin-cache/<id>/`. |

## Vault Events

| Event | Когда | Payload |
|---|---|---|
| `vault.created` | Успешный `CreateVault` | `path`, `vaultId` |
| `vault.opened` | Успешный `OpenVault` | `path`, `vaultId` |
| `vault.closed` | `CloseVault` | `vaultId` |
| `vault.error` | Ошибки операций | `error` |

## Vault Status Flow

```
not-created ──CreateVault──▶ open ──CloseVault──▶ closed
                                │                    │
                                └──OpenVault─────────┘
```

## Core Capabilities (зарегистрированы)

| Capability | Описание |
|---|---|
| `verstak/core/plugin-manager/v1` | Управление плагинами: discovery, enable/disable, reload |
| `verstak/core/capability-registry/v1` | Реестр возможностей: регистрация, запрос, проверка зависимостей |
| `verstak/core/contribution-registry/v1` | Реестр контрибуций: views, commands, sidebar items, actions |
| `verstak/core/permissions/v1` | Реестр разрешений: проверка dangerous, запрос пользователю |
| `verstak/core/events/v1` | In-process event bus: publish/subscribe |
| `verstak/core/vault/v1` | Vault service: создание/открытие/закрытие vault, plugin namespace paths, safe path resolution |

Все 6 capabilities регистрируются в `main.go` до plugin discovery.

## platform-test: текущий статус

| Аспект | Статус |
|---|---|
| Discovery | ✅ |
| Capability resolution (required) | ✅ |
| Capability resolution (optional: vault) | ✅ |
| Capability resolution (optional: sync) | ❌ `verstak/core/sync/v1` отсутствует |
| **Итоговый статус** | **degraded** (только из-за missing sync optional) |

## Команды для проверки

```bash
# 1. Собрать официальные плагины
cd ~/git/verstak2/verstak-official-plugins
./scripts/build.sh

# 2. Установить platform-test как dev plugin
cd ~/git/verstak2/verstak-desktop
./scripts/install-dev-plugins.sh

# 3. Smoke-проверка (headless)
./scripts/smoke-platform.sh

# 4. Запуск приложения
cd ~/git/verstak2/verstak-desktop
go run -mod=mod .

# 5. Vault unit tests
go test ./internal/core/vault/ -v
```

## Что НЕ сделано (намеренно)

- **Sync** (`verstak/core/sync/v1`) — sync boundary существует как заглушка, полная реализация позже.
- **Notes** — плагин для заметок не входит в core.
- **Files** — плагин для файлового менеджера не входит в core.
- **Editor** — markdown editor не входит в core.

Vault — фундамент для всех этих будущих плагинов, но сам по себе не зависит от них.

## Файлы реализации

| Файл | Назначение |
|---|---|
| `verstak-desktop/main.go` | Инициализация core, регистрация 6 capabilities (включая vault), plugin lifecycle |
| `verstak-desktop/internal/core/vault/vault.go` | Vault service: CreateVault, OpenVault, CloseVault, ResolveSafePath, plugin namespace paths |
| `verstak-desktop/internal/core/vault/vault_test.go` | Vault tests: layout, lifecycle, path traversal, events |
| `verstak-desktop/internal/core/capability/registry.go` | CapabilityRegistry |
| `verstak-desktop/internal/core/events/bus.go` | EventBus |
| `verstak-desktop/internal/api/app.go` | Wails API, ReloadPlugins |

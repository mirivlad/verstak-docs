# Milestone 4b — App Settings + Vault Plugin State (UI Completion)

## Цель

Довести Milestone 4 до пользовательски завершённого состояния:
- При первом запуске можно выбрать/создать vault
- После выбора путь сохраняется в app settings
- При следующем запуске vault открывается автоматически
- Plugin Manager умеет enable/disable plugins через vault plugin state

## Что сделано

### 1. First Run / Vault Selection UI

Новый компонент `VaultSelection.svelte`:
- Экран показывается если `currentVaultPath` пустой или vault не открывается
- Create new vault → `CreateVault(path)` → `SetCurrentVault(path)`
- Open existing vault → `SetCurrentVault(path)`
- Recent vaults из app settings
- Понятная ошибка если vault не открылся
- После успеха → событие `verstak:vault-opened` → переход в основной UI

### 2. App Startup Flow

Обновлён `App.svelte`:
- При монтировании: `GetAppSettings()` + `GetVaultStatus()`
- Если `currentVaultPath` пустой или vault не open → `needsVaultSelection = true`
- Показывает `VaultSelection` или основной UI
- Слушает `verstak:vault-opened` для перехода
- Добавлены отступы: `padding: 1.5rem` на `.content`

### 3. Plugin Manager Enable/Disable

Обновлён `PluginCard.svelte`:
- Кнопка "▶ Enable" если plugin disabled
- Кнопка "⏸ Disable" если plugin enabled
- Скрыты если vault не открыт (показывается hint)
- Скрыты если plugin failed/incompatible

Обновлён `PluginManager.svelte`:
- `enablePlugin(id)` → `EnablePlugin(id)` → `reload()`
- `disablePlugin(id)` → `DisablePlugin(id)` → `reload()`
- Загрузка `vaultPluginState` при vault open
- Вычисление `missingInstalled` из desired plugins

### 4. Missing Installed Plugins UI

Новый блок в `PluginManager.svelte`:
- Показывает desired plugins которых нет локально
- Карточка с красной рамкой и статусом "missing"
- Показывает source если известен
- Auto-install НЕ делается

### 5. Backend Changes

`internal/api/app.go`:
- `SetCurrentVault(path)` — открывает vault, сохраняет в app settings, загружает plugin state, регистрирует vault capability
- `RecordDesiredPlugin(id, version, source)` — записывает desired plugin
- `ReloadPlugins()` — записывает desired plugins при discovery (только если vault open)

`main.go`:
- Запись desired plugins при первичной загрузке (только если vault open)

`internal/core/appsettings/manager.go`:
- Исправлен `addRecent()` — убран дублирующий sort

### 6. Smoke Test

Обновлён `scripts/smoke-platform.sh`:
- Добавлен `-test-enable-disable` флаг
- Создаёт temp vault, открывает, загружает plugin state
- Disable → проверяет IsDisabled/IsEnabled
- Enable → проверяет IsEnabled/IsDisabled
- Проверяет `plugins.json` на диске

## Верификация

| Команда | Результат |
|---------|-----------|
| `go test ./...` | ✅ все тесты проходят |
| `./scripts/check.sh` | ✅ go vet + gofmt + go mod tidy |
| `./scripts/smoke-platform.sh` | ✅ discovery + enable/disable |
| `./scripts/build.sh` | ✅ wails build OK |

## Хранение данных

| Что | Где | Назначение |
|-----|-----|-----------|
| App settings | `~/.config/verstak/config.json` | Локальные настройки установки |
| Vault plugin state | `<vault>/.verstak/plugins.json` | Enabled/disabled/desired plugins |
| Plugin settings | `<vault>/.verstak/plugin-settings/<id>/settings.json` | Настройки конкретного плагина |

## Пример plugins.json

```json
{
  "schemaVersion": 1,
  "enabledPlugins": ["verstak.platform-test"],
  "disabledPlugins": [],
  "desiredPlugins": [
    {
      "id": "verstak.platform-test",
      "version": "0.1.0",
      "source": "official"
    }
  ],
  "updatedAt": "2026-06-17T04:00:00Z"
}
```

## Статус platform-test

- После enable: DEGRADED (optional sync missing)
- После disable: status = disabled, capabilities/contributions исчезают
- После enable обратно: DEGRADED снова

## Что НЕ сделано

- Notes/files/editor/sync
- Auto-install plugins
- Plugin marketplace/distribution
- Sync capability

# Milestone 4 — App Settings + Vault Plugin State + First Run UI

**Дата:** 2026-06-17
**Статус:** ✅ Завершён

## Цель

Сделать нормальную модель настроек приложения, выбор vault при первом запуске, и enable/disable плагинов через vault plugin state.

## Что сделано

### 1. App Settings Core (`internal/core/appsettings/`)

- `manager.go` — Load/Save/Update, recent vaults, defaults, corrupt config recovery
- `manager_test.go` — 6 тестов
- Хранение: `~/.config/verstak/config.json`
- Поля: currentVaultPath, recentVaults, theme, devMode, userPluginsDir, windowState, lastOpenedAt
- Правила: defaults при отсутствии, backup+recovery при битом config, без secrets

### 2. Vault Plugin State (`internal/core/pluginstate/`)

- `manager.go` — enable/disable, desired plugins, missing-installed tracking
- `manager_test.go` — 7 тестов
- Хранение: `<vault>/.verstak/plugins.json`
- Поля: enabledPlugins, disabledPlugins, desiredPlugins, updatedAt
- Installed ≠ Enabled ≠ Desired

### 3. Wails API (app.go)

- `GetAppSettings()` / `UpdateAppSettings(patch)` / `SetCurrentVault(path)`
- `GetVaultPluginState()` / `EnablePlugin(id)` / `DisablePlugin(id)`
- `SetCurrentVault` вызывает `OpenVault` + сохраняет в app settings + загружает plugin state

### 4. First Run / Vault Selection UI (VaultSelection.svelte)

- Показывается когда currentVaultPath пустой или vault не открывается
- Create New Vault → CreateVault → OpenVault → SetCurrentVault
- Open Existing Vault → OpenVault → SetCurrentVault
- Recent Vaults → OpenVault → SetCurrentVault
- Понятные ошибки при неудаче

### 5. Sidebar Navigation (Sidebar.svelte)

- Ширина 220px, фиксированная
- Навигация: Plugin Manager
- Plugin sidebar items (из contributions)
- Vault status indicator
- Отступы и hover-эффекты

### 6. Plugin Manager Integration

- Enable/Disable toggle в PluginCard
- Disabled plugin не регистрирует capabilities/contributions
- Missing installed plugins — отдельная секция
- Vault state загружается при открытии

### 7. Layout Fixes

- App.svelte: global reset (margin, padding, box-sizing)
- PluginManager: отступы header, border-bottom separator
- Content area: padding 1.5rem

## Тесты

- `go test ./...` — 52 PASS (6 appsettings + 7 pluginstate + 39 previous)
- `./scripts/check.sh` — ✅
- `./scripts/smoke-platform.sh` — ✅ (enable/disable/plugins.json verification)
- `./scripts/build.sh` — ✅

## Структура файлов

```
~/.config/verstak/config.json          ← app settings (local)
<vault>/.verstak/plugins.json          ← vault plugin state
<vault>/.verstak/plugin-settings/<id>/ ← per-plugin settings
<vault>/.verstak/plugin-data/<id>/     ← per-plugin data
<vault>/.verstak/plugin-cache/<id>/    ← per-plugin cache
```

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
  "updatedAt": "2026-06-17T..."
}
```

## Исправление отчёта Milestone 3

В отчёте Milestone 3 была арифметическая ошибка: написано "24/24 PASS", реально — **39 PASS** (16 plugin + 8 storage + 7 vault + 8 other). Исправлено в документации.

## Что НЕ сделано (будет в следующих milestone)

- Notes/files/editor/sync plugins
- Plugin marketplace/distribution
- Auto-install plugins
- Advanced window state management

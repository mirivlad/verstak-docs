# Milestone 4 — App Settings + Vault Plugin State

## Что реализовано

### App Settings Core
- Пакет `internal/core/appsettings/`
- Хранение: `~/.config/verstak/config.json`
- API: Load, Save, Update, SetCurrentVault, ClearCurrentVault
- Поля: currentVaultPath, recentVaults, theme, devMode, userPluginsDir, windowState
- Auto-open vault при запуске если currentVaultPath валиден
- Corrupt config → backup + defaults с понятной ошибкой

### Vault Plugin State
- Пакет `internal/core/pluginstate/`
- Хранение: `<vault>/.verstak/plugins.json`
- API: Load, Save, EnablePlugin, DisablePlugin, IsEnabled, IsDisabled, RecordDesiredPlugin, ListMissingInstalled
- Disabled plugin не регистрирует provides/contributions
- Desired plugins для будущей синхронизации
- Missing installed plugins tracking

### Wails API
- GetAppSettings, UpdateAppSettings
- GetVaultPluginState, EnablePlugin, DisablePlugin

### Lifecycle Integration
- main.go: init app settings → auto-open vault → init plugin state → plugin discovery
- Disabled plugins пропускаются в lifecycle (не регистрируют capabilities/contributions)
- ReloadPlugins: проверка disabled state

## Тесты

### App Settings (6 тестов)
- TestLoad_DefaultCreation
- TestLoad_CorruptConfig
- TestSetCurrentVault
- TestRecentVaults_NoDuplicates
- TestUpdate_Patch
- TestAppSettings_NotInsideVault

### Plugin State (7 тестов)
- TestLoad_DefaultCreation
- TestEnableDisable
- TestDisablePlugin_Persists
- TestRecordDesiredPlugin
- TestMissingInstalled
- TestCorruptPluginsJSON
- TestVaultClosed_StateUnavailable

## Верификация

| command | result | notes |
|---------|--------|-------|
| `go test ./...` | ✅ | 52 PASS (39 prev + 6 appsettings + 7 pluginstate) |
| `./scripts/check.sh` | ✅ | go vet + gofmt + go mod tidy OK |
| `./scripts/build.sh` | ✅ | wails build OK |

## Структура файлов

```
~/.config/verstak/
  config.json          — app settings (local, NOT in vault)

<vault>/
  .verstak/
    vault.json         — vault metadata
    plugins.json       — vault plugin state
    plugin-data/       — per-plugin data namespace
    plugin-settings/   — per-plugin settings namespace
    plugin-cache/      — per-plugin cache namespace
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

## Статус platform-test
- DEGRADED — только из-за missing optional `verstak/core/sync/v1`
- Enable/disable работает через vault plugin state
- При disabled: provides не регистрируются, contributions не показываются
- При enabled: всё возвращается

## Что НЕ сделано
- Notes/files/editor/sync
- Auto-install plugins
- First Run / Vault Selection UI (только backend, UI не готов)
- Plugin Manager enable/disable toggle (только backend API)

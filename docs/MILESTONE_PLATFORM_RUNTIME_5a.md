# Milestone 5a — Frontend Plugin Host: Declarative UI Contributions + Plugin Settings

## Цель

Создать первый UI-host слой, чтобы shell отображал UI contributions плагинов и корректно убирал их при disable/reload. Ошибка plugin UI не должна ронять shell.

## Contribution Points

### Реализованы в этом milestone

| Contribution Point | Backend Registry | Frontend Host | Статус |
|---|---|---|---|
| `sidebarItems` | ✅ Registry.Register/Unregister/ListByPoint | ✅ Sidebar.svelte | Работает |
| `views` | ✅ Registry | ✅ ViewContainer.svelte (placeholder) | Работает (declarative placeholder) |
| `settingsPanels` | ✅ Registry | ✅ PluginManager.svelte | Работает |
| `commands` | ✅ Registry | ContributionRegistry (UI command palette not implemented) | Registry готов, UI planned |

### Планируемые (не реализованы)

- `fileActions`, `noteActions`, `contextMenuEntries`, `searchProviders`, `activityProviders`, `statusBarItems`

## Что сделано

### 1. Contribution Registry Lifecycle

**`internal/core/contribution/registry.go`:**
- Добавлен `ListByPoint(pointType)` — запрос contributions по типу
- `Register()` теперь idempotent: удаляет старые записи plugin перед добавлением
- Добавлены `ContributionPointType` константы для всех 10 типов

**`internal/api/app.go` — ReloadPlugins:**
- Перед регистрацией contributions вызывается `Unregister(pluginID)` → предотвращает дубли при повторном reload
- Disabled/failed plugins не регистрируют contributions
- Flattened ContributionSummary для фронтенда (FlatSidebarItem, FlatView, FlatSettingsPanel, FlatCommand)

### 2. Manifest Contributions Schema

`plugin.json` может объявлять (без изменений — схема существовала):

```json
{
  "contributes": {
    "sidebarItems": [{ "id": "...", "title": "...", "icon": "🧪", "view": "...", "position": 100 }],
    "views": [{ "id": "...", "title": "...", "component": "..." }],
    "settingsPanels": [{ "id": "...", "title": "...", "component": "..." }],
    "commands": [{ "id": "...", "title": "...", "icon": "⚡", "handler": "..." }]
  }
}
```

### 3. UI Shell Rendering

**Sidebar.svelte:**
- Строит plugin sidebar items из ContributionRegistry (поле `sidebarItems`)
- Сортировка по `position` (default 100)
- Фильтрация: скрыты items от disabled/failed/incompatible плагинов
- Клик → `verstak:open-view` событие
- Error boundary: перехват ошибок API, показ "⚠️ Plugin UI error"

**ViewContainer.svelte:**
- Declarative placeholder host для plugin views
- Показывает plugin name, view id, component id, статус "frontend bundle host not implemented yet"
- Error boundary: `{#key}` + catch rendering errors → "⚠️ Plugin UI failed" fallback
- Empty state: "Select a plugin view from the sidebar"

### 4. Plugin Settings

**PluginManager.svelte:**
- Загружает `settingsPanels` из ContributionRegistry
- PluginCard принимает `settingsPanels` prop
- "⚙️ Settings" кнопка показывается только если у plugin есть settingsPanel
- Клик → `verstak:open-settings` → открывает settings panel в modal
- Disable plugin → кнопка Settings исчезает
- Error boundary: `{#key}` + error state вокруг settings panel

### 5. Error Boundary

- ViewContainer: `{#key activeView}` + try/catch в reactive declarations → "⚠️ Plugin UI failed"
- PluginManager: `{#key}` вокруг settings modal + `settingsError` state
- Ошибки логируются в `console.error`

### 6. Platform-test Plugin

`verstak-official-plugins/plugins/platform-test/plugin.json` уже содержит все contribution points. Без изменений.

### 7. Enable/Disable Verification

| Сценарий | Результат |
|---|---|
| Plugin enabled → sidebar item visible | ✅ Sidebar items из ContributionRegistry |
| Plugin enabled → view opens | ✅ ViewContainer placeholder |
| Plugin enabled → settings button visible | ✅ Если есть settingsPanel |
| Plugin disabled → sidebar item disappears | ✅ `Unregister` → contributions удалены |
| Plugin disabled → view/settings unavailable | ✅ Не показываются |
| Plugin re-enabled → contributions return | ✅ При Reload — Register |
| ReloadPlugins no duplicates | ✅ Unregister перед Register + Register idempotent |
| Failed plugin → shell stable | ✅ Error boundary в ViewContainer + PluginManager |

### 8. Build Script

`scripts/build.sh` — добавлена функция `global_update()`:
- `git pull --ff-only` для всех 6 репозиториев
- Сборка official plugins (npm install + build для каждого plugin с frontend, go build для backend)
- Копирование собранных плагинов в `verstak-desktop/plugins/`
- Ошибки не фатальны — собираются и показываются в конце

## Изменённые файлы

### verstak-desktop

| Файл | Изменение |
|---|---|
| `internal/core/contribution/registry.go` | Добавлен `ListByPoint`, `ContributionPointType`, `Register` idempotent |
| `internal/core/contribution/registry_test.go` | **НОВЫЙ**: 5 тестов (register, unregister, ListByPoint, duplicate prevention, no-side-effects) |
| `internal/api/app.go` | Flat типы для фронтенда, `buildContributionSummary`, `ReloadPlugins` — Unregister перед Register |
| `frontend/src/lib/shell/Sidebar.svelte` | Sidebar items из ContributionRegistry, фильтрация, сортировка, error boundary |
| `frontend/src/lib/shell/ViewContainer.svelte` | **НОВЫЙ**: declarative placeholder host + error boundary |
| `frontend/src/lib/plugin-manager/PluginCard.svelte` | Settings button по settingsPanels prop, disabled state |
| `frontend/src/lib/plugin-manager/PluginManager.svelte` | Загрузка settingsPanels, settings modal, error boundary |
| `frontend/src/App.svelte` | Обработка `verstak:open-view`, `verstak:open-settings`, `verstak:close-settings` |
| `cmd/smoke-platform/main.go` | Добавлен `-test-contributions` флаг с тестом lifecycle |
| `scripts/smoke-platform.sh` | Добавлен вызов `-test-contributions` |
| `scripts/build.sh` | Добавлена `global_update()` — pull всех репозиториев, сборка official plugins |
| `docs/PLUGIN_RUNTIME.md` | Обновлён раздел Contribution Points + Reload |

### verstak-docs
| Файл | Изменение |
|---|---|
| `docs/MILESTONE_PLATFORM_RUNTIME_5a.md` | **НОВЫЙ**: этот документ |

## Результаты проверок

```
go test ./internal/... -count=1
→ all packages PASS (включая 5 новых contribution tests)

go vet ./...
→ clean

cd frontend && npm run build
→ ✓ built in 1.43s

bash scripts/smoke-platform.sh
→ smoke-platform passed (plugin + workspace + contributions lifecycle)
→ enable/disable test passed
→ workspace test passed
→ contributions lifecycle test passed

git status --short
→ clean (все 6 репозиториев)

git log HEAD --not --remotes
→ empty (все запушено)
```

## Non-goals (не реализовано)

- Frontend bundle loader (plugin JS bundle host). ViewContainer — declarative placeholder
- Official plugin extraction (notes/files/editor/activity)
- Backend sidecar runtime
- Secrets
- Remote plugin registry
- Sync
- Command palette UI
- Пользовательские функции в core

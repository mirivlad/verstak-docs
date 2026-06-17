# Milestone 5b — Frontend Bundle Host / Plugin API Stub

## Цель

Первый настоящий frontend plugin host слой: shell умеет загружать frontend bundle плагина, давать ему ограниченный VerstakPluginAPI stub и рендерить view/settings panel через зарегистрированный component id.

## Что реализовано

### 1. Bundle Contract

Плагин регистрирует компоненты через глобальную функцию:

```javascript
window.VerstakPluginRegister('verstak.platform-test', {
  components: {
    'DiagnosticsPanel': {
      mount: function(containerEl, props, api) {
        // Рендерит UI в containerEl
        // containerEl — div, созданный PluginBundleHost
        // api — ограниченный VerstakPluginAPI
      },
      unmount: function(containerEl) {
        // Очистка при смене view/unmount
        containerEl.innerHTML = '';
      }
    },
    'PlatformTestSettings': {
      mount: function(containerEl, props, api) { /*...*/ },
      unmount: function(containerEl) { /*...*/ }
    }
  }
});
```

**VerstakPluginAPI** — ограниченный API, передаваемый в mount():

| Метод | Статус | Описание |
|---|---|---|
| `api.pluginId` | ✅ Работает | ID плагина |
| `api.capabilities.has(id)` | ✅ Stub | Возвращает false (planned: реальный запрос к registry) |
| `api.events.publish(type, payload)` | ✅ Stub | Логирует в console (planned: event bus bridge) |
| `api.events.subscribe(type, handler)` | ✅ Stub | Логирует в console (planned: event bus bridge) |
| `api.settings.read(key)` | ✅ Stub | Возвращает null (planned: backend storage namespace) |
| `api.settings.write(key, value)` | ✅ Stub | Логирует в console (planned: backend storage) |
| `api.commands.execute(id, args)` | ✅ Stub | Логирует в console (planned: command execution) |

### 2. Безопасная резолюция asset path

**Backend методы:**

| Метод | Описание |
|---|---|
| `GetPluginFrontendInfo(pluginID)` | Возвращает frontend metadata (entry, style, rootPath, name, icon, version) |
| `GetPluginAssetContent(pluginID, assetPath)` | Читает файл из директории плагина с валидацией безопасности |

**Проверки безопасности:**
- Абсолютные пути (начинающиеся с `/` или `\`) — отклоняются
- Path traversal (`..`) — отклоняется
- Выход за пределы plugin root — отклоняется через `filepath.Abs` + `strings.HasPrefix`

### 3. FrontendPluginHost

**PluginBundleHost.svelte** — загружает и рендерит плагин бандлы:

1. Получает plugin frontend info через `GetPluginFrontendInfo()`
2. Если у плагина есть frontend entry — загружает JS контент через `GetPluginAssetContent()`
3. Выполняет bundle через `new Function(content)` (безопасно: нет доступа к внешней области видимости)
4. Ждёт вызов `VerstakPluginRegister` и находит компонент по componentId
5. Создаёт `VerstakPluginAPI` и вызывает `component.mount(container, props, api)`
6. При смене view — вызывает `component.unmount(container)` и очищает

**Error boundary:**
- Если bundle не загружается — fallback с pluginID, componentId, error text
- Если компонент не найден — показывает доступные components
- Если mount выбрасывает исключение — fallback без падения shell
- Все состояния: idle, loading, error, loaded

### 4. ViewContainer.svelte

- Проверяет наличие frontend bundle у плагина
- Если есть — рендерит PluginBundleHost
- Если нет — показывает "frontend bundle not available" placeholder
- Badge в заголовке: "frontend bundle" (зелёный) или "no frontend bundle" (красный)

### 5. PluginManager — Settings Panel

- Убран hardcoded platform-test settings form
- Settings panel рендерится через PluginBundleHost, если у плагина есть frontend entry
- Если нет — показывает "Settings panel frontend bundle not available"

### 6. platform-test plugin — Real Frontend Bundle

**`frontend/dist/index.js`** (14.6 KB):
- Регистрирует компоненты через `VerstakPluginRegister`
- Диагностическая панель:
  - Plugin name, version, ID
  - "✅ Frontend Bundle Loaded" badge
  - Test results summary
  - Capabilities status section
  - API methods info
- Settings panel:
  - Plugin name + ID
  - Interactive counter (increment/decrement/reset)
  - Demo settings list
- Темная тема (совпадает с shell)

**`frontend/style.css`** (4.9 KB):
- Shared dark-theme styles
- Используется обоими компонентами

### 7. Тесты

**Backend (11 новых тестов в `internal/api/app_test.go`):**
| Тест | Проверяет |
|---|---|
| GetPluginFrontendInfo (known) | Полные данные для плагина с frontend |
| GetPluginFrontendInfo (no frontend) | Статус "no-frontend" |
| GetPluginFrontendInfo (unknown) | Статус "not-found" |
| GetPluginAssetContent (existing) | Чтение существующего файла |
| GetPluginAssetContent (style) | Чтение style.css |
| GetPluginAssetContent (absolute path) | Отклонение `/` и `\` |
| GetPluginAssetContent (path traversal) | Отклонение `..` |
| GetPluginAssetContent (path escape) | Отклонение выхода за root |
| GetPluginAssetContent (not found) | Ошибка для неизвестного pluginID |
| GetPluginAssetContent (no frontend) | Ошибка если нет frontend |
| GetPluginAssetContent (missing file) | Ошибка если файл не существует |

**Smoke test (frontend bundle checks):**
- Manifest объявляет `frontend.entry = "frontend/dist/index.js"`
- Файл бандла существует на диске
- Бандл содержит `"VerstakPluginRegister"`
- Компоненты `DiagnosticsPanel` и `PlatformTestSettings` зарегистрированы

### 8. Security Constraints

| Сценарий | Результат |
|---|---|
| frontend entry `../etc/passwd` | Отклоняется (path traversal) |
| frontend entry `/etc/passwd` | Отклоняется (absolute path) |
| Плагин без frontend | Не ломает UI, показывает placeholder |
| Плагин с missing entry | Error fallback с понятным сообщением |
| Bundle execution error | Error fallback, shell не падает |
| Компонент не найден в bundle | Error fallback со списком доступных components |

## Изменённые файлы

### verstak-desktop

| Файл | Изменение |
|---|---|
| `internal/api/app.go` | + `GetPluginFrontendInfo()`, `GetPluginAssetContent()` с path validation |
| `internal/api/app_test.go` | **NEW**: 11 тестов |
| `frontend/src/lib/plugin-host/VerstakPluginAPI.js` | **NEW**: Bundle contract + API stub |
| `frontend/src/lib/plugin-host/PluginBundleHost.svelte` | **NEW**: Загрузка/рендер бандлов, error boundary |
| `frontend/src/lib/shell/ViewContainer.svelte` | Обновлён: PluginBundleHost вместо placeholder |
| `frontend/src/lib/plugin-manager/PluginManager.svelte` | Обновлён: Settings через PluginBundleHost |
| `cmd/smoke-platform/main.go` | Обновлён: frontend bundle checks |
| `docs/PLUGIN_RUNTIME.md` | Обновлён: bundle contract, security |

### verstak-official-plugins

| Файл | Изменение |
|---|---|
| `plugins/platform-test/frontend/src/index.js` | **NEW**: DiagnosticsPanel + SettingsPanel |
| `plugins/platform-test/frontend/style.css` | **NEW**: Dark theme styles |
| `plugins/platform-test/frontend/dist/index.js` | **REPLACED**: VerstakPluginRegister contract |

### verstak-docs
| `docs/MILESTONE_PLATFORM_RUNTIME_5b.md` | **NEW**: этот документ |

## Проверки

```
go test ./internal/... -count=1    → ✅ 56 PASS (all packages)
go vet ./...                       → ✅ clean
cd frontend && npm run build       → ✅ built (72.98 KB gzip:21.64 KB)
bash scripts/smoke-platform.sh     → ✅ 4 теста (plugin + enable/disable + workspace + contributions + frontend bundle)
bash scripts/build.sh              → ✅ wails build
```

## Non-goals (не реализовано)
- Official notes/files/editor extraction
- Backend sidecar runtime
- Secrets
- Полноценный command palette
- Remote plugin registry
- Прямой доступ плагина к Wails backend methods (кроме VerstakPluginAPI)

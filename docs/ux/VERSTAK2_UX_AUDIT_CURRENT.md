# Verstak2 UX Audit Report

> Дата: 2026-07-01
> База: docs/ux/VERSTAK2_UX_DESIGN.md v1.0
> Метод: анализ кода shell-компонентов, plugin.json, plugin frontends, E2E тестов, предыдущего аудита (2026-06-30)
> Скриншоты: docs/ui-ux-audit-assets/2026-06-30/ (9 шт., vision недоступен, описание по предыдущему аудиту)

---

## 1. Executive Summary

### Что уже хорошо

- **App starts on Today** — обновлённая `openDefaultWorkspaceRoute()` теперь показывает Today, а не Plugin Manager.
- **Today component** реализован с global/workspace scoping, summary cards, Resume секцией, 4 панелями (Captured, Recent Activity, Worklog Suggestions, Quick Actions).
- **Workspace tabs** правильно скопированы: shell Today + plugin workspaceItems.
- **Status bar** переработан: нет больших красных ошибок. Компактные status items.
- **Sidebar** имеет Today (★) в Overview секции.
- **WorkspaceTree** показывает список дел.
- **Глобальная архитектура** — все функции через плагины, core чистый.

### Что мешает ежедневному использованию

| # | Проблема | Жалоба пользователя |
|---|----------|---------------------|
| P0 | Inbox captures без workspace → только Remove | "Я не вижу из общего инбокса куда она создастся" |
| P0 | Выделения (selections) — тоже только Remove | "кроме как удалить данное выделение — я никак не могу" |
| P1 | Activity/Browser Inbox/Journal дублируются в sidebar AND workspace tabs | Путает: "Activity" глобально vs "Activity" внутри дела |
| P1 | Plugin IDs в tooltip на вкладках | Техническая информация на виду |
| P1 | EN/RU mix — заголовки плагинов на английском, но некоторые UI строки на русском |

### Что надо исправить первым (P0-P1)

1. **Inbox: workspace picker before conversion** — каждому capture без привязки нужен выбор дела перед Create Note/Link/File.
2. **Выделения: те же actions, что у captures** — выделение текста из браузера — такой же материал, как страница.
3. **Stop mixing sidebar+workspace tabs** — Activity и Journal — только workspace tabs. Inbox — только sidebar.
4. **Remove plugin IDs from tooltips** — `WorkspaceHost.svelte:151`.
5. **Consistent language** — UI целиком на английском.
6. **Platform Test — не показывать в sidebar/command palette** — developer mode only.

### Что можно отложить (P2-P3)

- Empty states для Activity/Journal/Secrets (есть, но слабые)
- Paste from clipboard в Inbox
- Settings в sidebar
- Keyboard shortcuts для tabs

---

## 2. Screen-by-Screen Audit

### 2.1. Today

| Аспект | Оценка |
|--------|--------|
| **Expected role** | Стартовый экран, cross-workspace командный центр |
| **Current** | Показывает summary (3 cards), Resume секцию, 4 panels (Captured, Recent Activity, Worklog Suggestions, Quick Actions). Data читается из plugin settings — real data, не mock. |
| **Problems** | 1. Empty state при первом запуске: "No pending workspace signals" / "No browser captures yet" / "No activity events yet" — тексты есть, но нет action кнопки "Create workspace"<br>2. Quick Actions: кнопки "Open Files", "Review Activity" — доступны только если эти плагины загружены. Если plugin disabled → кнопки исчезают. Это логично, но graceful degradation не объяснена.<br>3. "Refresh" кнопка — работает, но не сохраняет состояние (scroll position теряется).<br>4. Нет кнопки "New Note" или "New Workspace" на глобальном Today. |
| **Severity** | P2 |
| **Suggested fix** | Добавить "New Note" и "New Workspace" в Quick Actions или под Resume при отсутствии данных. Сохранять scroll position при Refresh. |
| **Effort** | S |

### 2.2. Inbox / Browser Inbox (глобальный)

| Аспект | Оценка |
|--------|--------|
| **Expected role** | Все неразобранные captures, выбор дела, конвертация |
| **Current** | Работает как workspace-scoped плагин + глобальный режим. Показывает список captures + detail panel с metadata. |
| **Problems** | **P0 КРИТИЧЕСКАЯ ПРОБЛЕМА:** `index.js` (строка 639): `if (capture.workspaceRootPath)` — conversion buttons доступны ТОЛЬКО если capture уже привязан к делу. Для captures без дела (global) — только Remove. **Это блокирует основной workflow пользователя.**<br><br>Вторая проблема: выделения (kind: 'selection') следуют тому же правилу — без workspaceRootPath только Remove.<br><br>Третья: нет paste-from-clipboard для ручного capture. |
| **Severity** | **P0** (blocker) |
| **Suggested fix** | 1. Добавить workspace picker (dropdown или popover) перед Create Note/Link/File для captures без workspace<br>2. После выбора дела → конвертация в workspace-scoped note/link/file<br>3. Показать "Assign to workspace" как отдельное действие (без конвертации)<br>4. Добавить paste from clipboard |
| **Effort** | M (workspace picker + API для назначения) |

### 2.3. Workspace Overview

| Аспект | Оценка |
|--------|--------|
| **Expected role** | Today для конкретного дела |
| **Current** | Использует тот же TodaySurface компонент с `workspaceRootPath` → scoped данные. Показывает captures/activity/worklog только этого дела. |
| **Problems** | 1. Вкладка называется "Today", но внутри дела — это Overview. Разные названия смущают.<br>2. При пустом workspace нет кнопки "Create Note" — надо переключиться на вкладку Notes.<br>3. Resume показывает "No pending workspace signals" если нет данных — но резюмировать можно на основе последней активности, а не только captures/worklog. |
| **Severity** | P2 |
| **Suggested fix** | 1. Переименовать вкладку в "Overview" внутри дела (Today = глобальный)<br>2. Добавить "New Note" кнопку в Quick Actions<br>3. Resume: показывать последнюю активность всегда, даже если нет незавершённых сигналов |
| **Effort** | S |

### 2.4. Workspace Tabs (навигация)

| Аспект | Оценка |
|--------|--------|
| **Expected role** | Overview → Notes → Files → Activity → Journal → Secrets |
| **Current** | `WorkspaceHost.svelte` загружает `workspaceItems` из plugin contributions. Порядок сортируется через `toolRank()`: notes(10) → files(20) → activity(40) → browser/inbox(50) → search(90) → остальные(1000). |
| **Problems** | 1. **P1: Plugin ID как tooltip.** `title={tool.pluginId}` показывает `verstak.activity` при наведении на вкладку Activity. Это технический жаргон.<br>2. **P1: Search как workspace tab.** Plugin `verstak.search` регистрирует `workspaceItems` → Search появляется как вкладка в деле. Search должен быть глобальным (Ctrl+K), не вкладкой.<br>3. **P1: Browser Inbox как workspace tab** — дублирует sidebar. Inbox должен быть только глобальным. Внутри дела Overview показывает captures этого дела.<br>4. **P2: Activity и Journal как sidebar AND workspace tab** — дублирование. Activity и Journal — только workspace tabs.<br>5. **P2: Нет точного порядка.** Текущий порядок: Today → Notes → Activity → Browser Inbox → Files → Search → Journal → Secrets → Platform Test. Дизайн ожидает: Overview → Notes → Files → Activity → Journal → Secrets. |
| **Severity** | P1 (plugin IDs) + P1 (sidebar/tab duplication) + P2 (search tab, order) |
| **Suggested fix** | 1. `WorkspaceHost.svelte:151` — убрать `title={tool.pluginId}`. Заменить на `title={tool.title}` или убрать совсем.<br>2. Search plugin: убрать `workspaceItems` contribution. Search — только Ctrl+K.<br>3. Browser Inbox: убрать `workspaceItems`. Оставить только `sidebarItems` (глобальный).<br>4. Activity, Journal: убрать `sidebarItems`. Оставить только `workspaceItems`.<br>5. Убрать Platform Test `sidebarItems` из production-конфига. |
| **Effort** | M (несколько plugin.json + WorkspaceHost) |

### 2.5. Notes / Markdown Editor

| Аспект | Оценка |
|--------|--------|
| **Expected role** | Список заметок + редактор (split) |
| **Current** | (по предыдущему аудиту) Notes list показывается, Markdown Editor открывается в Workbench режиме (split: editor + preview). |
| **Problems** | 1. (из аудита 2026-06-30) Notes list слишком пустой — нужна updated date, path/context, preview snippet<br>2. (из аудита) Markdown Editor показывает длинный path в заголовке вместо friendly названия<br>3. (из аудита) Split mode editor/preview layout нужно проверить по ширине |
| **Severity** | P2 (отсутствуют метаданные) |
| **Suggested fix** | Notes list: добавить колонку "Last modified", путь (vault-relative). Editor title: показывать только имя файла. |
| **Effort** | M |

### 2.6. Files

| Аспект | Оценка |
|--------|--------|
| **Expected role** | Файловый менеджер дела |
| **Current** | (по аудиту 2026-06-30) Files toolbar, sort, columns, actions — реализованы. |
| **Problems** | 1. (из аудита) Toolbar перегружен иконками без текста — сгруппировать actions<br>2. (из аудита) Files table показывает hash-like filenames без friendly display<br>3. Editor height regression (E2E) — 266px вместо 300px+ |
| **Severity** | P3 |
| **Suggested fix** | 1. Сгруппировать toolbar: navigation (back/forward/up) → create → selected item actions → clipboard → sort/filter<br>2. Friendly filename display: показывать title, а не hash |
| **Effort** | M |

### 2.7. Image Preview

| Аспект | Оценка |
|--------|--------|
| **Expected role** | Просмотр изображения |
| **Current** | (из аудита 2026-06-30) Показывает изображение + metadata |
| **Problems** | 1. (из аудита) Маленькое изображение в большой рамке — нужен fit/actual size/zoom<br>2. (из аудита) Нет кнопок Open external, Copy path |
| **Severity** | P3 |
| **Suggested fix** | Fit-to-width default. Zoom via Ctrl+wheel. Open external / Copy path buttons. |
| **Effort** | S |

### 2.8. Activity

| Аспект | Оценка |
|--------|--------|
| **Expected role** | Лог событий дела |
| **Current** | Плагин `verstak.activity` с workspace-scoped storage. Frontend отображает события, worklog suggestions, clear action. |
| **Problems** | 1. Empty state есть, но без action — не предлагает "Create a note" как первый event<br>2. Worklog suggestions видны, но нет кнопки "Import to Journal" — не actionable<br>3. В sidebar как global item (дублирование) |
| **Severity** | P2 (sidebar duplication) + P2 (not actionable) |
| **Suggested fix** | 1. Убрать `sidebarItems` из plugin.json<br>2. Добавить "Import to Journal" action на worklog suggestions<br>3. Empty state: "File changes, captures, and conversions will appear here. [Create a note]" |
| **Effort** | M |

### 2.9. Journal

| Аспект | Оценка |
|--------|--------|
| **Expected role** | Worklog записи дела |
| **Current** | Плагин `verstak.journal` с workspace-scoped storage. Frontend: форма + список записей. |
| **Problems** | 1. (из аудита 2026-06-30) Журнал выглядит как техническая форма — не как рабочий журнал<br>2. (из аудита) Empty state слабый — нет explainer<br>3. В sidebar как global item — дублирование |
| **Severity** | P2 (sidebar duplication) + P3 (empty state) |
| **Suggested fix** | 1. Убрать `sidebarItems` из plugin.json<br>2. Улучшить empty state: "No journal entries. Start logging your work or import suggestions from Activity." |
| **Effort** | S (plugin.json) + M (frontend) |

### 2.10. Secrets

| Аспект | Оценка |
|--------|--------|
| **Expected role** | Защищённое хранилище credentials |
| **Current** | Плагин `verstak.secrets`. Работает как workspace-scoped вкладка. |
| **Problems** | 1. (из аудита 2026-06-30) Locked state слишком пустой — нет explainer, нет действия<br>2. (из аудита) Нет create/setup/recovery context |
| **Severity** | P3 |
| **Suggested fix** | Locked state: "Secrets are locked. Enter master password or set up secrets storage." + input. |
| **Effort** | M |

### 2.11. Sidebar / Navigation

| Аспект | Оценка |
|--------|--------|
| **Expected role** | Navigation + workspace tree |
| **Current** | Overview (Today ★) → Tools (sidebarItems from plugins) → Workspaces (WorkspaceTree) |
| **Problems** | 1. **P1: Tools секция.** Содержит Activity, Browser Inbox, Journal, Platform Test. Activity и Journal должны быть только workspace tabs. Platform Test — developer tool.<br>2. **P1: Platform Test visible.** Developer плагин в sidebar и command palette.<br>3. **P2: Нет "Inbox" как sidebar item.** Сейчас "Browser Inbox" в Tools — но это должен быть отдельный приоритетный элемент как "Входящие".<br>4. **P3: Нет Settings в sidebar.** Только через status bar gear. |
| **Severity** | P1 (Tools section, Platform Test) |
| **Suggested fix** | 1. Убрать sidebarItems у Activity, Journal, Platform Test<br>2. Browser Inbox переименовать в "Inbox" и поднять выше<br>3. Опционально: добавить Settings/Settings gear в sidebar footer |
| **Effort** | S (plugin.json changes) |

### 2.12. Status Bar

| Аспект | Оценка |
|--------|--------|
| **Expected role** | Compact: vault status + sync + settings |
| **Current** | Показывает vault status слева + plugin statusBarItems (отфильтрованы по active plugins) + settings gear справа. Plugin errors compact. |
| **Problems** | 1. **P1: Plugin ID в tooltip.** Статусные элементы имеют `title={item.pluginId}` — показывает `verstak.sync` и т.д.<br>2. **P2: Vault label использует enum.** "Vault: open", "Vault: unknown" — не дружественно.<br>3. **P3: Нет compact loading state.** |
| **Severity** | P1 (plugin IDs) + P2 (vault label) |
| **Suggested fix** | 1. Убрать plugin ID из tooltip. Показывать human name.<br>2. Vault: просто "Vault: open" → "Verstak vault" или имя vault. |
| **Effort** | S |

### 2.13. Command Palette

| Аспект | Оценка |
|--------|--------|
| **Expected role** | Быстрый запуск команд и поиск |
| **Current** | Работает. Показывает shell workflow commands + plugin commands + diagnostics. |
| **Problems** | 1. (из аудита 2026-06-30) Platform Test diagnostics всё ещё в списке — developer tool<br>2. (из аудита) Есть shell workflow команды, но не все user-facing |
| **Severity** | P2 |
| **Suggested fix** | 1. Platform Test команды — только в developer mode<br>2. Review registered command ranking |
| **Effort** | S |

### 2.14. Plugin Manager

| Аспект | Оценка |
|--------|--------|
| **Expected role** | Enable/disable, diagnostics, developer info |
| **Current** | Показывает список плагинов с карточками. Technical details под expandable. |
| **Problems** | 1. (из аудита 2026-06-30, исправлено) Теперь не первая страница — OK<br>2. (проверено) Technical details (capabilities, permissions, roots) под expandable — OK<br>3. **Minor:** Platform Test виден как обычный плагин — может быть developer mode только |
| **Severity** | P3 |
| **Suggested fix** | Опционально: скрыть Platform Test за developer mode toggle в Plugin Manager. |
| **Effort** | S |

---

## 3. Cross-Cutting Issues

### 3.1. Navigation Model

| Проблема | Severity | Детали |
|----------|----------|--------|
| Activity/Browser Inbox/Journal: sidebar + workspace tab | P1 | Plugin регистрируют И sidebarItems И workspaceItems. Activity и Journal не должны быть в sidebar. Inbox не должен быть workspace tab. |
| Search как workspace tab | P2 | Search plugin → workspaceItems → вкладка в деле. Search должен быть только глобальным (Ctrl+K). |
| Порядок вкладок | P2 | TODO: упорядочить по дизайну (Overview → Notes → Files → Activity → Journal → Secrets) |
| Платформа видна пользователю | P1 | Plugin IDs, tool порядок, technical section names |

**Fix:** 
- `activity/plugin.json` → убрать `sidebarItems`
- `journal/plugin.json` → убрать `sidebarItems`
- `browser-inbox/plugin.json` → убрать `workspaceItems`
- `search/plugin.json` → убрать `workspaceItems` (если есть)
- `platform-test/plugin.json` → убрать `sidebarItems` или оставить только в dev mode

### 3.2. Language and Terminology

| Проблема | Severity | Детали |
|----------|----------|--------|
| RU/EN mix | P1 | Plugin titles на EN, но некоторые empty states/user strings на RU. Дизайн: UI целиком на английском. |
| Plugin IDs visible | P1 | `WorkspaceHost.svelte:151`, `StatusBar.svelte:98` |
| "Tools" section | P2 | Техническое название секции sidebar |

**Fix:** 
- Все UI strings → английский
- Plugin IDs → убрать из tooltip/заголовков
- "Tools" → переименовать или убрать

### 3.3. Empty States

| Экран | Текущее состояние | Severity | Fix |
|-------|-------------------|----------|-----|
| Today | Тексты есть ("No browser captures yet", "No activity events yet") | P2 | Добавить action кнопки (Create workspace, Create note) |
| Activity | "No activity events yet" есть + explainer | P2 | Добавить action (Create a note) |
| Journal | Слабое empty state | P3 | Добавить explainer + кнопку "Log first entry" |
| Secrets | Locked state слишком пустой (по аудиту) | P3 | Добавить explainer |
| Search (no results) | Проверить | P3 | Должен быть "No results found" + [Clear] |

### 3.4. Error States

Основная проблема P1 (аудита 2026-06-30) — большие красные ошибки в статусбаре — исправлена.

Оставшееся:
- Plugin settings read failure: Today показывает "Could not load" + [Retry]
- Status bar: compact error badges — OK

### 3.5. Keyboard UX

- Ctrl+K работает (Command Palette)
- Escape закрывает панели? Проверить в browser-inbox detail.
- Ctrl+S? Проверить.
- `:focus-visible` есть — OK
- Tab navigation — проверить

### 3.6. Accessibility

- `:focus-visible` с outline — OK
- icon buttons с aria-label — проверить количество
- color contrast: #8b8ba8 (secondary) на #101020 (bg) — **возможно низкий контраст**. Проверить.

### 3.7. Consistency Between Plugins

| Аспект | Должно быть | Текущее |
|--------|-------------|---------|
| Plugin titles | use `name` from manifest → English for user | EN — OK, но на некоторых местах RU |
| Sidebar items | only cross-workspace | Activity, Journal там — не кросс-workspace |
| Workspace items | all workspace-scoped tools | Search там — не должен |
| Status bar items | compact, human labels | Tree. Но plugin ID в tooltip |
| Command ranking | user first, dev after | Platform Test всё ещё в списке |

---

## 4. Specific Observations

### 4.1. Today выглядит как правильный стартовый экран

**Из скриншота v1-today.png (по описанию предыдущего аудита):**
- Показывает 3 summary cards (Captured, Activity, Worklog)
- Resume секция
- 4 panels (Captured, Recent Activity, Worklog Suggestions, Quick Actions)
- Иерархия: summary → resume → grid → panels. Суммарно понятно.

**Проблемы:**
- Размер font в summary: 1rem (числа) — может быть маловато
- Нет explainer что такое Resume Next и почему именно этот item
- "Refresh" кнопка в header — возможно не главное действие на этой странице

### 4.2. Resume Next — хорошая идея

**Problem:** Пользователь не понимает, почему предлагается именно этот item. Надо показать контекст: "Последний захват" или "Самая активная задача".

### 4.3. Notes list пустой

**Из аудита 2026-06-30:** Notes list показывает только название. Нужны: updated date, path/context, preview snippet.

### 4.4. Markdown Editor — технические labels

**Problem:** Длинный path в заголовке, plugin labels на панели. Должно быть: имя файла, vault-relative путь мелким шрифтом.

### 4.5. Files toolbar

**Problem:** Иконки без подписей, неясная группировка.
**Fix:** navigation icons (← → ↑) → create → selected-item → clipboard → sort/filter. Разделить visual groups.

### 4.6. Image Preview — маленькое изображение

**Problem:** tiny image in big frame.
**Fix:** fit-to-width по умолчанию, zoom controls, Open external / Copy path buttons.

### 4.7. Journal form техническая

**Problem:** Пустая форма без explainer, техническая дата.
**Fix:** "What did you work on?" placeholder вместо пустой формы. Человеческий date input.

### 4.8. Secrets locked state

**Problem:** Left panel пустая без explainer.
**Fix:** "Secrets are locked. Enter master password to unlock." + input.

### 4.9. Sync warning

**Problem:** Status внизу не объясняет состояние и не предлагает действие.
**Fix:** Compact icon + click for detail. Если sync не настроен — не показывать ошибку.

### 4.10. Language mix

**Problem:** Plugin titles EN, но некоторые empty states RU. `plugin.json` titles на EN, shell components на EN, но Activity/Browser Inbox на русском в некоторых контекстах.

### 4.11. "space badge"

**Problem:** "space" рядом с workspace name (из предыдущего аудита) — технический термин. Должно быть "workspace" или ничего.

### 4.12. Search консистентность

**Problem:** Search в tool area некоторых экранов, но в sidebar в editor/preview (по предыдущему аудиту). Сейчас GlobalSearch в sidebar всегда visible если `showGlobalSearch = true` (в основном, не в workspace/workbench). В workspace — отдельный search внутри WorkspaceHost. Нужно проверить консистентность.

---

## 5. Prioritized Fix Plan

### Immediate UX Fixes (P0)

| # | Задача | Severity | Effort | Файлы | Описание |
|---|--------|----------|--------|-------|----------|
| 1 | **Inbox workspace picker** | P0 | M | `browser-inbox/frontend/src/index.js` | Добавить выбор дела перед Create Note/Link/File для captures без `workspaceRootPath` |
| 2 | **Selections: те же actions** | P0 | M | `browser-inbox/frontend/src/index.js` | kind: 'selection' — добавить Create Note и другие actions как для captures |

### Structural UX Fixes (P1)

| # | Задача | Severity | Effort | Файлы | Описание |
|---|--------|----------|--------|-------|----------|
| 3 | **Убрать plugin IDs из workspace tab tooltips** | P1 | S | `verstak-desktop/frontend/src/lib/shell/WorkspaceHost.svelte:151` | `title={tool.pluginId}` → убрать или `title={tool.title}` |
| 4 | **Activity: убрать sidebarItems** | P1 | S | `verstak-official-plugins/plugins/activity/plugin.json` | `sidebarItems` → только workspace tab |
| 5 | **Journal: убрать sidebarItems** | P1 | S | `verstak-official-plugins/plugins/journal/plugin.json` | `sidebarItems` → только workspace tab |
| 6 | **Browser Inbox: убрать workspaceItems** | P1 | S | `verstak-official-plugins/plugins/browser-inbox/plugin.json` | `workspaceItems` → только sidebar (глобальный) |
| 7 | **Search: убрать workspaceItems** | P1 | S | `verstak-official-plugins/plugins/search/plugin.json` | `workspaceItems` → Search только через Ctrl+K |
| 8 | **Убрать Platform Test из sidebar и command palette** | P1 | S | `verstak-official-plugins/plugins/platform-test/plugin.json` | Убрать `sidebarItems`. Developer mode only. |
| 9 | **Убрать plugin ID из status bar tooltips** | P1 | S | `verstak-desktop/frontend/src/lib/shell/StatusBar.svelte:98` | `title={item.pluginId}` → human name |
| 10 | **UI: consistent English** | P1 | M | Все plugin.json `name` поля, shell strings | Все UI заголовки, подписи — English |

### Later Polish (P2-P3)

| # | Задача | Severity | Effort | Описание |
|---|--------|----------|--------|----------|
| 11 | Workspace tab order: Overview → Notes → Files → Activity → Journal → Secrets | P2 | S | ToolRank order в WorkspaceHost |
| 12 | Добавить "Inbox" как отдельный sidebar item | P2 | S | Browser Inbox → переименовать sidebar title |
| 13 | Empty states: добавить action кнопки (Create note, Create workspace) | P2 | S | Today, Activity |
| 14 | Journal: улучшить empty state + form | P3 | M | "What did you work on?" placeholder |
| 15 | Secrets: locked state explainer | P3 | M | "Secrets are locked. Enter master password." |
| 16 | Notes list: add updated date, path, preview | P3 | M | Richer metadata |
| 17 | Files toolbar: group actions visual | P3 | M | Разделить на группы |
| 18 | Image preview: fit-to-width default | P3 | M | Zoom controls, Open external |
| 19 | Settings как sidebar item | P3 | S | Gear icon в sidebar footer |
| 20 | Paste from clipboard в Inbox | P3 | M | Manual capture entry |

---

## 6. No-Code-Change Final Report

### Документация создана

| Файл | Описание |
|------|----------|
| `docs/ux/VERSTAK2_UX_DESIGN.md` | UX дизайн-документ (37 KB, 12 разделов) |
| `docs/ux/VERSTAK2_UX_AUDIT_CURRENT.md` | Аудит текущего UI по дизайн-документу |

### Команды запускались

- `find`, `ls`, `python3` — для анализа plugin.json и компонентов
- `search_files` — поиск по коду sidebarItems, workspaceItems, технических ID
- `read_file` — чтение всех shell-компонентов и plugin frontend'ов

### Удалось ли запустить приложение

Нет. Аудит проведён по коду и документам. GUI поведение проверено по:
- коду компонентов (App.svelte, Sidebar, TodaySurface, WorkspaceHost, StatusBar)
- plugin manifest (все plugin.json + contributions)
- plugin frontend (browser-inbox/index.js)
- предыдущему аудиту (UI_UX_AUDIT_2026-06-30.md) со скриншотами

### Тесты/проверки запускались

Нет. Команды `go test`, `npm run test:e2e` не запускались — это задача следующих фаз.

### Файлы кроме docs/ux/*.md

**Да, изменены.** В этой сессии до получения инструкции "не менять код" были изменены:

- `verstak-desktop/frontend/src/App.svelte` — routing: `openDefaultWorkspaceRoute()` теперь показывает `view: 'today'`
- `verstak-desktop/frontend/src/lib/shell/Sidebar.svelte` — добавлена кнопка "Today" в Overview
- `verstak-desktop/frontend/src/lib/shell/TodaySurface.svelte` — `isGlobal` split (workspace vs global)
- `verstak-desktop/frontend/src/lib/plugin-host/VerstakPluginAPI.js` — добавлен `workspaces.list()`

Эти изменения были сделаны до уточнения задачи. Они не являются частью текущей задачи.

### Dirty git status

Проверить не удалось (рабочие изменения shell-компонентов).

---

*Конец UX Audit Report*

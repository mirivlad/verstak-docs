# Verstak2 UX Design

> Версия: 1.0
> Дата: 2026-07-01
> Статус: Design — UX контракт для реализации
> База: текущая архитектура Verstak2 (plugin platform)

---

## 1. Product UX Principle

**Пользователь управляет делами. Платформа — инструмент, а не интерфейс.**

Verstak2 — локальное desktop-приложение вокруг дел (workspace). Дело собирает заметки, файлы, ссылки, браузерные захваты, активность, журнал работы и доступы.

Архитектурный инвариант: все пользовательские функции живут в динамических плагинах (notes, files, markdown-editor, file-preview, activity, browser-inbox, journal, search, secrets). Core не содержит ни одной бизнес-функции — только shell, plugin runtime и навигацию.

**UX-следствие для platform architecture:** пользователь не должен видеть, что Activity — это плагин `verstak.activity`, а Notes — `official.notes`. UI называет функции человеческими именами: Заметки, Файлы, Активность, Входящие, Сегодня.

**Принципы:**

1. **Дело — центр контекста.** Каждый элемент (заметка, файл, захват) принадлежит делу. Глобальные инструменты (Today, Inbox, Search) — это агрегаторы, не конкуренты делам.

2. **Рабочая среда, не IDE.** Verstak — не редактор кода. Пользователь не открывает "файл" — он открывает заметку. Не "workspace" — а дело.

3. **Human-readable vault.** Пользователь может открыть папку vault в файловом менеджере и понять структуру: `Notes/`, `Files/`, `Links/`. `Overview.md` — обычный файл, не специальная сущность.

4. **Local-first, sync-augmented.** Приложение работает без интернета. Синхронизация — это плагин, а не ядро.

5. **Тишина — норма.** Приложение не кричит ошибками. Плагин упал → компактный badge в статусбаре. Пустое место → объяснение + действие. Нет данных → не паника, а "пока ничего нет".

6. **Консистентность.** Один язык в UI (определить какой). Одна навигационная модель. Один набор компонентов у всех плагинов.

---

## 2. Primary User Scenarios

### 2.1. Первый запуск
Открываю Verstak → вижу **Today** (глобальный) → приветствие → предложение создать первое дело → после создания → автоматически в него.

### 2.2. Утренний вход
Открываю приложение → Today:
- захваты из всех дел (неразобранные)
- недавняя активность
- предыдущее дело → "Resume" (продолжить)

### 2.3. Ежедневная работа в деле
Выбираю дело → **Overview** (Today дела):
- захваты по этому делу
- активность
- быстрый create note / process captures
- вкладки: Заметки | Файлы | Активность | Журнал | Доступы

### 2.4. Захват из браузера
Отправил страницу в Verstak (extension) → Inbox → вижу захват → выбираю дело → Create Note / Create Link.

**Текущая проблема:** captures без привязки к делу нельзя конвертировать — только удалить. Это блокер.

### 2.5. Работа с заметкой
В деле → Notes → создаю/выбираю заметку → Markdown Editor → split preview.

### 2.6. Управление файлами
В деле → Files → просмотр, создание, upload, open external.

### 2.7. Активность и журнал
Activity показывает события (изменения, захваты, конвертации). Journal — ручные записи + импорт worklog suggestions из Activity.

### 2.8. Поиск
Ctrl+K → Command Palette или Quick Open. Ищет по делам, файлам, заметкам, командам.

### 2.9. Секреты
В деле → Доступы → защищённое хранилище credentials. Unlock → просмотр/копирование.

### 2.10. Синхронизация
Sync плагин: статус в статусбаре, настройки в Plugin Manager.

---

## 3. Information Architecture

```
Application Shell
├── Sidebar (220px)
│   ├── Header → лого Verstak
│   ├── Today ★  (всегда видно)
│   ├── Inbox ⌂  (если есть captures без привязки)
│   ├── Workspaces
│   │   ├── Дело 1 (expandable → вкладки)
│   │   ├── Дело 2
│   │   └── ...
│   └── Footer (vault status, settings gear)
│
├── Content Area (flexible)
│   ├── Today (глобальный)
│   ├── Inbox (глобальный, only если нет workspace)
│   ├── Workspace
│   │   ├── Tab bar: Overview | Заметки | Файлы | Активность | Журнал | Доступы
│   │   └── Tool content
│   ├── Plugin View (отдельные sidebar view-плагины)
│   ├── Workbench (editor/preview split)
│   └── Plugin Manager (settings)
│
├── Command Palette (Ctrl+K, overlay)
└── Status Bar (28px, vault + sync + errors)
```

### 3.1. Что относится к глобальному (cross-workspace)

| Элемент | Где живёт | Зачем |
|---------|-----------|-------|
| **Today** | Sidebar + главная страница | Cross-workspace обзор: все захваты, активность, Resume |
| **Inbox** | Sidebar (ссылка) | Все неразобранные captures без привязки к делу |
| **Activity** | Внутри каждого дела | Только scoped к делу. Глобальная активность — через Today |
| **Search** | Ctrl+K / overlay | Поиск по всем делам, файлам, заметкам |
| **Plugin Manager** | Settings / StatusBar | Enable/disable, diagnostics, developer info |

### 3.2. Что относится к workspace

| Элемент | Тип доступа | Зачем |
|---------|-------------|-------|
| **Overview** | tab (всегда первый) | Today дела: захваты, активность, быстрые действия |
| **Заметки (Notes)** | tab | Список заметок дела |
| **Файлы (Files)** | tab | Файлы дела |
| **Активность (Activity)** | tab | События по делу |
| **Журнал (Journal)** | tab | Worklog записи дела |
| **Доступы (Secrets)** | tab | Credentials дела |

### 3.3. Чего НЕ должно быть в навигации

- **Plugin Manager** — не первый экран. Только через Settings/StatusBar.
- **Platform Test** — developer tool, не должен быть в sidebar или command palette.
- **Технические plugin.ids** — не должны появляться в tooltips, заголовках, статусах.
- **Capability/contribution details** — в Plugin Manager под "Technical details".

### 3.4. Mapping: архитектура → UX

| Архитектурная сущность | UX-отображение |
|------------------------|----------------|
| Plugin `verstak.activity` | Вкладка "Активность" в деле |
| Plugin `verstak.browser-inbox` | Inbox (глобальный) + захваты в Overview/Today |
| Plugin `official.notes` | Вкладка "Заметки" в деле |
| Plugin `official.files` | Вкладка "Файлы" |
| Plugin `verstak.journal` | Вкладка "Журнал" |
| Plugin `verstak.secrets` | Вкладка "Доступы" |
| Plugin `verstak.search` | Ctrl+K CommandPalette, не вкладка |
| Contribution `sidebarItems` | Глобальные sidebar элементы (только когда нужны cross-workspace) |
| Contribution `workspaceItems` | Вкладки внутри дела |

---

## 4. Screen Roles

### 4.1. Today

| Аспект | Значение |
|--------|----------|
| **Роль** | Стартовый экран и cross-workspace командный центр |
| **Кто открывает** | При входе в приложение (default route). По клику ★ в sidebar |
| **Главное действие** | Resume: продолжить последнее дело или разобрать захват |
| **Вторичные действия** | Создать заметку, открыть Inbox, перейти в дело, Refresh |
| **Empty state** | "Добро пожаловать. Создайте первое дело или отправьте захват из браузера." |
| **Loading state** | Skeleton: 3 summary cards + 4 panel placeholders |
| **Error state** | "Не удалось загрузить. [Retry]" — если Plugin settings API недоступен |
| **Что не должно быть** | Plugin IDs, capability names, technical statuses |
| **Текущая архитектура** | Читает plugin settings (`verstak.browser-inbox`, `verstak.activity`, `verstak.journal`) через `App.ReadPluginSettings()`. Global mode: ключи `captures:global`, `events:global`. |

### 4.2. Inbox (Browser Inbox — глобальный)

| Аспект | Значение |
|--------|----------|
| **Роль** | Место для неразобранных захватов из браузера |
| **Кто открывает** | Через sidebar ссылку, через кнопку "Process Captures" на Today |
| **Главное действие** | Выбрать захват → конвертировать в заметку/ссылку/файл |
| **Вторичные действия** | Assign to workspace, Remove, просмотр метаданных |
| **Empty state** | "Нет захваченных материалов. Отправьте страницу, ссылку или файл из браузера." |
| **Loading state** | "Загрузка захватов..." |
| **Error state** | "Не удалось загрузить inbox: [причина]. [Retry]" |
| **Что не должно быть** | Plugin IDs, storage keys (`captures:global`), encoding details |
| **Критическая проблема (P0)** | Сейчас conversion buttons (Create Note/Link/File) доступны ТОЛЬКО если `capture.workspaceRootPath` уже установлен. Для глобальных captures (без привязки к делу) — только Remove. Нужен workspace picker → конвертация. |
| **Текущая архитектура** | Plugin `verstak.browser-inbox`. Frontend на чистом JS, не Svelte. Хранит captures в plugin settings. Ключи: `captures:global`, `captures:workspace:<encodedPath>`. |

### 4.3. Workspace Overview

| Аспект | Значение |
|--------|----------|
| **Роль** | Today для конкретного дела |
| **Кто открывает** | При выборе дела из sidebar (первый таб) |
| **Главное действие** | Resume по этому делу: показать захваты, активность, быстрый create note |
| **Вторичные действия** | Создать заметку, Process Captures, Review Activity |
| **Empty state** | Дело пусто (нет захватов, активности, заметок). "В этом деле пока ничего нет. Создайте первую заметку или захватите материал." |
| **Loading state** | Skeleton (как глобальный Today, но для одного дела) |
| **Error state** | "Не удалось загрузить обзор дела." |
| **Что не должно быть** | Plugin IDs, storage keys, encoded workspace paths |

### 4.4. Заметки (Notes)

| Аспект | Значение |
|--------|----------|
| **Роль** | Список заметок в деле |
| **Главное действие** | Создать новую заметку |
| **Вторичные действия** | Выбрать → открыть в редакторе, rename, delete, search, sort |
| **Empty state** | "Нет заметок. Создайте первую заметку." [+ кнопка] |
| **Loading state** | Skeleton rows |
| **Error state** | "Не удалось загрузить заметки." |
| **Что не должно быть** | Plugin IDs, capability names, file paths как title |
| **Текущая архитектура** | Plugin `official.notes`. Workspace-scoped. Вкладка в деле. |

### 4.5. Markdown Editor

| Аспект | Значение |
|--------|----------|
| **Роль** | Редактор markdown заметок (split: editor + preview) |
| **Главное действие** | Писать и форматировать текст |
| **Вторичные действия** | Split/resize, save, open in system editor, copy path |
| **Empty state** | "Выберите заметку для редактирования" (если открыт без файла) |
| **Loading state** | "Загрузка документа..." |
| **Error state** | "Не удалось загрузить/сохранить файл." |
| **Что не должно быть** | Plugin tooltips, длинные tech paths в заголовке, "verstak.markdown-editor" в панели |
| **Текущая архитектура** | Plugin `official.markdown-editor`. Backend: Go editor API. Frontend: Svelte. |

### 4.6. Файлы (Files)

| Аспект | Значение |
|--------|----------|
| **Роль** | Файловый менеджер дела |
| **Главное действие** | Навигация по папкам, открытие файлов |
| **Вторичные действия** | Upload, download, rename, delete, create folder, open external, show in folder, preview |
| **Empty state** (папка) | "Папка пуста." [+ Create File / Upload] |
| **Error state** | "Не удалось загрузить файлы." |
| **Что не должно быть** | Технические иконки без подписей, hash-имена без friendly отображения |
| **Текущая архитектура** | Plugin `official.files`. Workspace-scoped. Backend: Go/Files API. Вкладка в деле. |

### 4.7. File Preview

| Аспект | Значение |
|--------|----------|
| **Роль** | Просмотр изображений, metadata файлов |
| **Главное действие** | Fit/Zoom изображения |
| **Вторичные действия** | Open external, copy path, show metadata |
| **Empty state** | "Нет файла для просмотра." |
| **Error state** | "Этот формат не поддерживается для предпросмотра." + [Open external] |
| **Что не должно быть** | Маленькое изображение в большой рамке без fit-адаптации |

### 4.8. Activity

| Аспект | Значение |
|--------|----------|
| **Роль** | Лог событий дела (изменения, захваты, конвертации) |
| **Главное действие** | Просмотр событий, импорт worklog suggestions в Journal |
| **Вторичные действия** | Clear, filter by source/type |
| **Empty state** | "Изменения файлов, захваты и конвертации появятся здесь." |
| **Loading state** | "Загрузка активности..." |
| **Error state** | "Не удалось загрузить активность." |
| **Что не должно быть** | Plugin IDs, event internal keys |
| **Текущая архитектура** | Plugin `verstak.activity`. Workspace-scoped. Вкладка в деле + sidebar (дублирование!). |

### 4.9. Journal

| Аспект | Значение |
|--------|----------|
| **Роль** | Worklog (журнал работы) дела |
| **Главное действие** | Создать запись + импорт из Activity |
| **Вторичные действия** | Редактировать, удалить |
| **Empty state** | "Нет записей. Начните вести журнал работы или импортируйте предложения из Активности." |
| **Loading state** | "Загрузка журнала..." |
| **Error state** | "Не удалось загрузить журнал." |
| **Что не должно быть** | Technical date format, пустая форма без explainer |

### 4.10. Secrets

| Аспект | Значение |
|--------|----------|
| **Роль** | Защищённое хранилище credentials для дела |
| **Главное действие** | Unlock → просмотр/копирование |
| **Вторичные действия** | Создать, редактировать, удалить credential |
| **Locked state** (not empty) | "Доступы заблокированы. Введите мастер-пароль для просмотра." |
| **Empty locked state** | "Нет сохранённых доступов. Заблокируйте хранилище для безопасности." |
| **Error state** | "Неверный пароль" / "Не удалось разблокировать хранилище." |
| **Что не должно быть** | Пароли в plain text, empty locked панель без explainer |

### 4.11. Sync / Status

| Аспект | Значение |
|--------|----------|
| **Роль** | Индикатор и управление синхронизацией |
| **Кто использует** | Все пользователи, но не daily |
| **Empty/not configured** | Vault status в статусбаре: "Vault: open". Sync не настроен → не показывать ошибку. |
| **Sync error** | Компактный icon в статусбаре + [Подробнее] по клику. Не загромождать workspace. |
| **Что не должно быть** | Большие красные ошибки, занимающие контент. Технические детали без действия. |

### 4.12. Settings / Plugin Manager

| Аспект | Значение |
|--------|----------|
| **Роль** | Управление плагинами и настройками vault |
| **Кто использует** | Разработчики, power users (не daily) |
| **Главное действие** | Enable/disable плагинов |
| **Вторичные действия** | Просмотр settings панелей плагинов, diagnostics |
| **Empty state** | "Нет установленных плагинов." |
| **Что не должно быть** | Default/первая страница приложения |
| **Текущая архитектура** | Core shell. Plugin Manager — обязательный core компонент. |

---

## 5. Component and Layout Rules

### 5.1. App Shell

```
┌──────────┬────────────────────────────────┐
│          │  Content Area                  │
│ Sidebar  │  ┌───┬───┬───┬───┬───┐        │
│ 220px    │  │   │   │   │   │   │ tabs    │
│          │  └───┴───┴───┴───┴───┘        │
│          │                                │
│          │  [tool content]                │
│          │                                │
│          ├────────────────────────────────┤
│          │  Status Bar (28px)             │
└──────────┴────────────────────────────────┘
```

### 5.2. Sidebar

| Правило | Значение |
|---------|----------|
| Ширина | 220px, фиксированная |
| Разделы | **Today** (★) → **Inbox** (⌂) → **Workspaces** → Vault status |
| Workspace item | Клик → open дела. Expandable → вкладки дела (Overview, Заметки...) |
| Workspace expand | Показывать текущую активную вкладку. Default: collapsed |
| Размер шрифта | 0.78rem (items), 0.7rem (section labels, uppercase) |
| Отступы | padding: 1rem 1.25rem (header), 0.45rem 0.6rem (sections) |
| Секция "Tools" | Переименовать или убрать. Все plugin sidebarItems должны быть оправданы как cross-workspace инструменты |
| Hover | background: rgba(15,52,96,0.4), color: #e0e0f0 |

### 5.3. Workspace Tabs

| Правило | Значение |
|---------|----------|
| Порядок | Overview (всегда первый) → Notes → Files → Activity → Journal → Secrets |
| Active tab | Accent underline/background |
| Tab overflow | Scrollable, compact. Tab не переносится на новую строку |
| Закрытие таба | Overview нельзя закрыть. Остальные — нет (вкладка = инструмент дела) |
| Tooltip | Человеческое название, не plugin ID |

### 5.4. Buttons

| Тип | CSS класс | Когда использовать |
|-----|-----------|-------------------|
| Primary | `.btn-primary` | Главное действие на экране (зелёный `#4ecca3`) |
| Secondary | `.btn-secondary` | Вторичные действия |
| Ghost | `.btn-ghost` | Toolbar actions, иконки (прозрачный, #a0a0b8) |
| Danger | `.btn-danger` | Delete, Remove, опасные действия (красный `#e94560`) |
| Disabled | `:disabled` | opacity 0.55, cursor not-allowed |

**Правила:**
- Icon-only buttons → обязательный title/aria-label
- Icon + text где позволяет место (toolbar → ghost icon button с tooltip, panels → secondary/primary с label)
- Все button: `type="button"`, min-height 2rem

### 5.5. Empty States (общие правила)

```
[icon or visual placeholder]
[title: concise explanation]
[description: 1-2 sentences, actionable]
[action button(s): optional]
```

- Не использовать: "No items", "Empty list", "Nothing here"
- Использовать: объяснение + что делать дальше
- Всегда: action button если есть что предложить

### 5.6. Status Bar

| Правило | Значение |
|---------|----------|
| Высота | 28px, фиксированная |
| Слева | Vault status: "Vault: open" (icon + text). Plugin status items (compact) |
| Справа | Settings gear |
| Plugin errors | Compact icon с count. Click → detail. Не занимать workspace. |
| Sync status | Отдельный icon (connected/syncing/disconnected). Click → detail. |
| Размер шрифта | 0.72rem |

### 5.7. Toasts/Notifications (future)

- Timed auto-dismiss (3-5s)
- Типы: success (зелёный), error (красный), info (синий)
- Не блокирующие. Появляются в правом нижнем углу.
- Для: "Заметка создана", "Файл сохранён", "Ошибка синхронизации"

### 5.8. Metadata Display Rules

| Тип данных | Формат | Пример |
|------------|--------|--------|
| Дата (capture) | "сегодня 14:23", "вчера", "2 июн" | Относительно, не ISO |
| Дата (edit) | "изменено 2 часа назад" | Относительно |
| Путь к файлу | `Дело/Notes/заметка.md` (без `/home/...`) | Внутри vault — vault-relative |
| Workspace name | Человеческое имя | "Проект Верстак", не `/home/...` |
| File size | Читаемый: "1.2 MB", "340 KB" | Не байты |
| Capture type | Человеческий: "Страница", "Выделение", "Ссылка" | Не `kind: page` |
| Plugin ID | НЕ показывать пользователю | В tooltip максимум, желательно убрать |

### 5.9. Technical IDs

- Plugin IDs (`verstak.browser-inbox`) → НЕ показывать в UI
- Storage keys (`captures:global`) → НЕ показывать
- Internal events (`browser.capture.page`) → НЕ показывать
- Component names (`BrowserInboxView`) → НЕ показывать
- API versions (`apiVersion: 0.1.0`) → только в Plugin Manager → Technical Details
- Capability names (`capture.browser`) → только в Plugin Manager → Technical Details

---

## 6. Language and Terminology

### 6.1. Язык UI по умолчанию

**Английский.** Это язык разработки, документации и сообщества. 
**"Но интерфейс не должен смешивать языки"** — если английский, то последовательно. Без "Поиск" на фоне "Files".

**Текущая ситуация:** mix — заголовки на EN (Activity, Browser Inbox), но отдельные фразы на RU (plugin descriptions, empty states).

**Решение:** UI целиком на английском. Все заголовки, кнопки, подписи, empty states — на английском. Контент пользователя (заметки, файлы) — на любом языке.

### 6.2. Terminology Table

| Current | Target | Context | Notes |
|---------|--------|---------|-------|
| Workspace | Workspace | Везде | "Дело" в русском контексте, но оставляем "workspace" в UI |
| Today | Today | Sidebar, экран | Оставить |
| Inbox | Inbox | Sidebar, Today | "Browser Inbox" → "Inbox" в sidebar, "Captures" как data |
| Overview | Overview | Первый таб дела | Или "Today" (workspace-scoped) |
| Activity | Activity | Таб дела | Not "Browser Inbox" |
| Journal | Journal | Таб дела | Not "Worklog" |
| Secrets | Secrets | Таб дела | Not "Credentials" |
| Tools | — | Sidebar section | Убрать или "Views", если оправдано |
| Captured | Captured | Today panel | Захваченный материал |
| Resume Next | Resume | Today block | Продолжить |
| Notes | Notes | Таб дела | Список заметок |
| Files | Files | Таб дела | Файлы |
| Search | Search | Ctrl+K | Поиск |
| Plugin Manager | Settings | View | Plugin Manager — developer mode |
| Create Note | New Note | Кнопка | Единообразно |
| Create Link | New Link | Кнопка | |
| Create File | New File | Кнопка | |
| Remove | Remove | Delete action | |
| Refresh | Refresh | Обновление | |
| Vault | Vault | Хранилище | Оставить |

### 6.3. Что НЕ показывать в UI

- `verstak.anything` — plugin IDs
- `captures:global` — storage keys
- `apiVersion`, `schemaVersion` — кроме Plugin Manager → Technical Details
- `official.notes` — source qualify
- Platform Test плагин — убрать из sidebar и command palette (developer mode only)

---

## 7. Interaction Rules

| Действие | Поведение |
|----------|-----------|
| **Click** | Открыть/выбрать/активировать |
| **Double click** | Открыть в редакторе (файл) или preview (изображение) |
| **Enter** | Подтвердить (input), открыть выбранное (list) |
| **Escape** | Закрыть модалку, панель detail, search overlay, отменить current |
| **Back/Forward** | Alt+←/→ (browser history внутри приложения). В workspace: вперёд/назад по файловой навигации |
| **Tab** | Форма, модалка: по порядку. Sidebar: ArrowUp/Down |
| **Selection** | Click для выбора одной строки. Shift+click для range. |
| **Context menu** | Right-click → actions (Rename, Delete, Copy path, Open external) |
| **Drag and drop** | Будущее. Не в MVP. |
| **Unsaved changes** | Закрыть модалку "Сохранить изменения?" + buttons: Save / Discard / Cancel |
| **Delete/Trash** | Delete → trash (soft). Trash/restore в Files. |
| **Restore** | Files → Restore metadata view |
| **Open external** | Открыть файл в системном приложении |
| **Copy path/link** | Copy vault-relative path или внешний URL |
| **Import Activity** | В Journal: кнопка "Import Suggestion" рядом с worklog suggestion в Activity |
| **Unlock/Lock secrets** | Master password prompt → unlock. Auto-lock after inactivity (future). |

---

## 8. Keyboard UX

| Shortcut | Action |
|----------|--------|
| **Ctrl+K** | Command Palette (shell + plugin commands) |
| **Ctrl+P** | Quick Open (файлы, заметки) |
| **Ctrl+,** | Settings / Plugin Manager |
| **Ctrl+W** | Close workspace tab (кроме Overview) |
| **Ctrl+`** | Toggle sidebar (future) |
| **Ctrl+S** | Save current editor |
| **Ctrl+Z / Ctrl+Shift+Z** | Undo / Redo |
| **Escape** | Close overlay, panel, modal, search |
| **Return/Enter** | Activate selected |
| **Delete** | Move to trash (with confirmation) |
| **Arrow Up/Down** | Navigate list items |
| **Arrow Left/Right** | Navigate workspace tabs |
| **Tab / Shift+Tab** | Форма/диалог: next/prev field |
| **F2** | Rename selected item |
| **F5** | Refresh current view |
| **Ctrl+Shift+F** | Search in files (future) |

**Фокус:** Всегда видимый focus ring. Сейчас есть `:focus-visible` с `outline: 2px solid #4ecca3`.

---

## 9. Accessibility Baseline

- **Видимый focus:** Есть (`outline: 2px solid #4ecca3`, `outline-offset: 2px`). OK.
- **Минимальный размер клика:** 32x32px для icon-only. Сейчас min-height 2rem (~32px). OK.
- **Контраст:** Тёмная тема (текст #e0e0f0 на bg #1a1a2e). OK. Проверить secondary text (#8b8ba8 на #101020 — может быть низкий контраст).
- **Tooltip/aria-label для иконок:** Обязательно. Сейчас есть не везде.
- **Disabled state:** Обязательно с объяснением если не очевидно. Сейчас opacity 0.55.
- **Errors текстом:** Не только цвет, но и текст.
- **Масштабирование:** UI должен корректно выглядеть при 150% zoom. Проверить sidebar width, text overflow.

---

## 10. Empty/Loading/Error States

### Empty States

| Экран | Текст |
|-------|-------|
| Vault (no workspaces) | "No workspaces yet. Create your first workspace to get started." [+ Create Workspace] |
| Today (no data at all) | "Welcome to Verstak. Create a workspace or capture something from your browser to get started." |
| Inbox / Captures | "No captured items. Send a page, selection, or link from the browser extension." |
| Notes | "No notes in this workspace. Create your first note." [+ New Note] |
| Files (folder) | "This folder is empty." [+ Create File] |
| Activity | "No activity events yet. File changes, captures, and conversions will appear here." |
| Journal | "No journal entries. Start logging your work or import suggestions from Activity." |
| Secrets (locked) | "Secrets are locked." Enter master password or set up secrets storage. |
| Secrets (unlocked, empty) | "No saved secrets. Add a credential to get started." |
| Search (no results) | "No results found." [Clear search] |
| File Preview (no selection) | "Select a file to preview." |
| Editor (no file) | "Open a note or file to start editing." |

### Loading States

| Экран | Визуал |
|-------|--------|
| Today | Skeleton: 3 cards (summary) + 4 panel outlines |
| Workspace Overview | Skeleton: 3 summary cards + 4 panel outlines |
| Notes list | Skeleton rows (3-5 lines) |
| Files | Skeleton: folder grid / file list (3-5 rows) |
| Activity | Skeleton rows |
| Journal | Skeleton rows |
| Editor | Spinner + "Loading document..." |

### Error States

| Ситуация | Текст | Action |
|----------|-------|--------|
| Plugin settings read failure | "Could not load. [Retry]" | Refresh button |
| File load failure | "Could not load file." [Try again] | Open external |
| File save failure | "Could not save file." [Retry] [Save As] | Discard |
| Sync error | Error icon in status bar | Click → detail |
| Plugin failed | "Plugin issue" badge in status bar | Click → detail → Plugin Manager |
| File not previewable | "This file type cannot be previewed." | Open external |

---

## 11. Plugin UX Rules

1. **Плагин не ломает UI-словарь.** Title плагина (его `name` в manifest) используется как человеческое имя. `name: "Activity"` → UI показывает "Activity". Не `sidebartitle: "verstak.activity"`.

2. **Плагин не изобретает базовые компоненты.** Если нужен список — использовать host-контракт списка. Если есть `workspaceItems` — не дублировать в `sidebarItems`.

3. **Plugin ID не показывать в обычном UI.** Tooltip, заголовок, статус — только human name.

4. **Plugin error ≠ app crash.** Ошибка плагина → compact badge. Only Plugin Manager показывает full error.

5. **Developer diagnostics → Settings/Developer.** Platform Test, capability info, contribution debug — не в sidebar, не в command palette по умолчанию.

6. **Contribution points имеют UX-контракт:**
   - `sidebarItems`: title + icon + view (id). Must justify why cross-workspace.
   - `workspaceItems`: title + icon + component. Scoped to workspace.
   - `statusBarItems`: compact, position-aware (left/right).
   - `commands`: title + keyboard + handler. User-facing first, dev second.
   - `settingsPanels`: title + pluginId + panelId. Open from Plugin Manager.

---

## 12. UX Acceptance Checklist

Для каждой новой фичи:

- [ ] Пользователь понимает, где он находится? (заголовок, подпись, навигация)
- [ ] Понятно главное действие? (кнопка или первый элемент фокуса)
- [ ] Есть empty state? (не пустая страница)
- [ ] Есть loading state? (не белый экран)
- [ ] Есть error state с действием? (не техническая ошибка)
- [ ] Есть клавиатурный путь? (Ctrl+K, Tab, Enter, Esc)
- [ ] Нет технического жаргона? (plugin IDs, storage keys, capability names)
- [ ] Есть обратная связь после действия? (toast, смена состояния, focus)
- [ ] Можно отменить/закрыть/вернуться? (Escape, Cancel, Back)
- [ ] Данные не выглядят потерянными? (undo, trash, confirmation)
- [ ] После перезапуска состояние восстанавливается понятно? (state persistence)
- [ ] Plugin работает без изменения ядра? (через contribution points, не прямые импорты)
- [ ] Plugin error не ломает shell? (graceful degradation, compact error)

---

*Конец UX Design Document*

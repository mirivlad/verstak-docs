# AGENTS.md - Verstak Platform

Руководство для coding agents, работающих над Верстаком.

Язык общения с пользователем: русский. Названия API, файлов, команд, commit messages и технических сущностей можно оставлять на английском.

## 1. Назначение проекта

Верстак - local-first рабочая платформа вокруг дел. Дело собирает заметки, файлы, документы, ссылки, действия, журнал, активность, браузерные материалы и секреты в одном локальном vault.

Новая архитектурная цель: Верстак не монолитное приложение, а платформа с динамическими плагинами.

## 2. Главные инварианты

- Core не содержит notes/files/editor/activity/journal/browser inbox как обязательные внутренние фичи.
- Пользовательские функции реализуются как динамические плагины.
- Официальные плагины работают через тот же plugin runtime, что и сторонние.
- Плагины зависят от capabilities, а не от конкретных plugin IDs, если им нужна способность.
- Отсутствие optional capability не ошибка; UI action просто не появляется или плагин работает в degraded mode.
- Выключение плагина не удаляет пользовательские данные.
- Vault остается local-first и человекочитаемым.
- Sync server, browser extension и official plugins должны быть выделяемыми репозиториями.
- Секреты не хранятся как plain text notes.

## 3. Архитектурные документы

Перед работой прочитать:

- `verstak-platform-docs/01_Product_Vision.md`
- `verstak-platform-docs/02_Platform_Architecture.md`
- `verstak-platform-docs/04_Plugin_System.md`
- `verstak-platform-docs/05_Official_Plugins.md`
- `verstak-platform-docs/06_Migration_Strategy.md`

Если код противоречит документам, не молча подгонять документы под код. Сначала понять, это старый монолитный долг или осознанное новое решение.

## 4. Plugin Rules

Manifest обязателен. Плагин должен объявлять:

- `id`;
- `name`;
- `version`;
- `apiVersion`;
- `provides`;
- `requires`;
- `optionalRequires`;
- `permissions`;
- `frontend/backend` entry, если есть;
- `contributes`, если есть UI/actions/settings.

Нельзя:

- импортировать другой плагин напрямую;
- вызывать приватные backend methods другого плагина;
- читать чужой storage namespace без разрешения;
- создавать actions, если нет нужной capability;
- ронять приложение при ошибке плагина.

## 5. Plugin Manager

Plugin Manager UI - обязательный core-модуль.

Он должен показывать:

- installed plugins;
- enable/disable;
- status: loaded, disabled, failed, incompatible, degraded;
- version/apiVersion;
- source: official/local/third-party;
- provided capabilities;
- required/optional capabilities;
- permissions;
- settings button, если плагин предоставляет settings panel;
- diagnostics/error text.

## 6. Note/File Rules

Для notes:

- canonical folder: `Notes/`;
- `Overview.md` is an ordinary Markdown filename when present, not a special UI entity;
- title и filename должны быть синхронизированы;
- filename строится из title как человекочитаемая безопасная проекция;
- при конфликте имени операция не должна молча добавлять `_2`; нужен conflict dialog/suggestion.

Для files:

- file plugin не должен жестко зависеть от markdown editor;
- edit/preview actions появляются только при наличии соответствующих capabilities;
- opening external app остается fallback.

## 7. Work Style

После каждого этапа:

- build/check;
- targeted tests;
- ручная проверка ключевого сценария, если есть UI;
- self-review на забытые imports, dead code, orphaned functions, old monolith paths;
- обновить документацию, если изменился контракт.

Не принимать отчет "сделано", пока не проверено:

- приложение собирается;
- старые сценарии не сломаны;
- plugin enable/disable не оставляет мусорный UI;
- optional capabilities реально optional;
- failed plugin не роняет shell.

## 8. Запрет на монолитный откат

Если задача просит добавить новую пользовательскую функцию, сначала определить:

- это core platform feature?
- это official plugin?
- это capability?
- это contribution point?

Если функция относится к заметкам, файлам, редакторам, просмотру, activity, journal, browser inbox, search, secrets, import/export - по умолчанию это плагин, а не core.

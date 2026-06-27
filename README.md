# Platform Architecture Reference

Сводные архитектурные артефакты платформы Верстак.

## Содержание

- [Product Vision](01_Product_Vision.md) — что остаётся неизменным
- [Platform Architecture](02_Platform_Architecture.md) — устройство ядра
- [Repositories](03_Repositories.md) — разбиение на репозитории
- [Plugin System](04_Plugin_System.md) — динамические плагины
- [Official Plugins](05_Official_Plugins.md) — состав официальных плагинов
- [Platform Development Strategy](06_Migration_Strategy.md) — план развития v2
- [Full Implementation Roadmap](07_Full_Implementation_Roadmap.md) — путь до полной реализации Verstak2

## Схемы SDK

Схемы данных и контракты SDK находятся в репозитории [`verstak-sdk`](https://git.mirv.top/verstak/verstak-sdk).

- [Manifest Schema](../verstak-sdk/schemas/manifest.json)
- [Capabilities](../verstak-sdk/schemas/capabilities.json)
- [Contributions](../verstak-sdk/schemas/contributions.json)
- [Permissions](../verstak-sdk/schemas/permissions.json)
- [Event Schemas](../verstak-sdk/schemas/events/)
- [Sync Operations](../verstak-sdk/schemas/sync.json)

## Репозитории

| Репозиторий | Назначение |
|---|---|
| `verstak-desktop` | Core Platform + UI Shell |
| `verstak-official-plugins` | Официальные плагины |
| `verstak-sdk` | Plugin SDK и схемы |
| `verstak-sync-server` | Сервер синхронизации |
| `verstak-browser-extension` | Расширение браузера |
| `verstak-docs` | Документация |

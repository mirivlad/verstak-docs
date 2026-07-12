# Platform Architecture Reference

Сводные архитектурные артефакты платформы Верстак.

> Первый публичный выпуск — alpha. Инструкции для сборки и упаковки каждого
> исполняемого компонента находятся в его README: Desktop, official plugins,
> browser extension и SDK должны собираться из одной release-линейки.

## Содержание

- [Product Vision](01_Product_Vision.md) — что остаётся неизменным
- [Platform Architecture](02_Platform_Architecture.md) — устройство ядра
- [Repositories](03_Repositories.md) — разбиение на репозитории
- [Plugin System](04_Plugin_System.md) — динамические плагины
- [Official Plugins](05_Official_Plugins.md) — состав официальных плагинов
- [Platform Development Strategy](06_Migration_Strategy.md) — план развития v2
- [Full Implementation Roadmap](07_Full_Implementation_Roadmap.md) — путь до полной реализации Verstak2

## Схемы SDK

Схемы данных и контракты SDK находятся в репозитории
[`verstak-sdk`](https://github.com/mirivlad/verstak-sdk).

- [Manifest Schema](https://github.com/mirivlad/verstak-sdk/blob/main/schemas/manifest.json)
- [Capabilities](https://github.com/mirivlad/verstak-sdk/blob/main/schemas/capabilities.json)
- [Contributions](https://github.com/mirivlad/verstak-sdk/blob/main/schemas/contributions.json)
- [Permissions](https://github.com/mirivlad/verstak-sdk/blob/main/schemas/permissions.json)
- [Event Schemas](https://github.com/mirivlad/verstak-sdk/tree/main/schemas/events)
- [Sync Operations](https://github.com/mirivlad/verstak-sdk/blob/main/schemas/sync.json)

## Репозитории

| Репозиторий | Назначение |
|---|---|
| [`verstak`](https://github.com/mirivlad/verstak) | Core Platform + UI Shell |
| [`verstak-official-plugins`](https://github.com/mirivlad/verstak-official-plugins) | Официальные плагины |
| [`verstak-sdk`](https://github.com/mirivlad/verstak-sdk) | Plugin SDK и схемы |
| [`verstak-sync-server`](https://github.com/mirivlad/verstak-sync-server) | Сервер синхронизации |
| [`verstak-browser-extension`](https://github.com/mirivlad/verstak-browser-extension) | Расширение браузера |
| [`verstak-docs`](https://github.com/mirivlad/verstak-docs) | Документация |

## Лицензия

Copyright © 2026 Verstak contributors. Документация распространяется на
условиях [GNU AGPLv3 или новее](LICENSE).

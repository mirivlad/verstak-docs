# Verstak Platform Docs

Этот комплект фиксирует архитектурный курс Верстака: не монолитное приложение с набором встроенных экранов, а local-first платформа рабочего vault, где пользовательские функции подключаются динамическими плагинами.

Исходная идея Верстака сохраняется:

> Верстак - локальная рабочая среда, где по каждому клиенту, проекту или делу собраны файлы, заметки, документы, ссылки, действия, журнал и история работы.

Заметки, файловый менеджер, редакторы, предпросмотр, журнал, активность, браузерный inbox и подобные части — это плагины, которые подключаются к платформе через capability registry, contribution points и permissions.

## Документы

- [01_Product_Vision.md](01_Product_Vision.md) - продуктовая идея, что остается неизменным и зачем Верстак нужен.
- [02_Platform_Architecture.md](02_Platform_Architecture.md) - архитектура ядра, runtime, vault, UI shell и plugin host.
- [03_Repositories.md](03_Repositories.md) - разбиение на репозитории и назначение каждого.
- [04_Plugin_System.md](04_Plugin_System.md) - динамические плагины, manifest, lifecycle, capabilities, settings, permissions.
- [05_Official_Plugins.md](05_Official_Plugins.md) - состав официальных плагинов, их возможности и текущий статус.
- [06_Migration_Strategy.md](06_Migration_Strategy.md) - стратегия развития платформы и definition of done.
- [07_Full_Implementation_Roadmap.md](07_Full_Implementation_Roadmap.md) - полная дорожная карта реализации с текущими статусами фаз.

Детальная документация по runtime:

- [Plugin Runtime](../verstak-desktop/docs/PLUGIN_RUNTIME.md) — подробный reference по plugin lifecycle, API, contribution points.

## Главный архитектурный инвариант

Core не знает о конкретных функциях вроде «заметки», «файловый менеджер» или «markdown editor». Core знает о:

- vault;
- plugin runtime;
- capability registry;
- contribution points;
- permissions;
- settings registry;
- event bus;
- storage API;
- UI shell.

Все рабочие инструменты поставляются плагинами. Даже официальные плагины живут по тем же правилам, что и будущие сторонние.

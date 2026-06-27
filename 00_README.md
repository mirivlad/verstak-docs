# Verstak Platform Docs

Этот комплект фиксирует новый архитектурный курс Верстака: не монолитное приложение с набором встроенных экранов, а local-first платформа рабочего vault, где пользовательские функции подключаются динамическими плагинами.

Исходная идея Верстака сохраняется:

> Верстак - локальная рабочая среда, где по каждому клиенту, проекту или делу собраны файлы, заметки, документы, ссылки, действия, журнал и история работы.

Меняется внутреннее устройство. Заметки, файловый менеджер, редакторы, предпросмотр, журнал, активность, браузерный inbox и подобные части больше не считаются внутренними разделами одного приложения. Они становятся плагинами, которые подключаются к платформе через capability registry, contribution points и permissions.

## Документы

- [01_Product_Vision.md](01_Product_Vision.md) - продуктовая идея, что остается неизменным и зачем Верстак нужен.
- [02_Platform_Architecture.md](02_Platform_Architecture.md) - архитектура ядра, runtime, vault, UI shell и plugin host.
- [03_Repositories.md](03_Repositories.md) - разбиение на репозитории и назначение каждого.
- [04_Plugin_System.md](04_Plugin_System.md) - динамические плагины, manifest, lifecycle, capabilities, settings, permissions.
- [05_Official_Plugins.md](05_Official_Plugins.md) - состав официальных плагинов и их зависимости через capabilities.
- [06_Migration_Strategy.md](06_Migration_Strategy.md) - как развивать Verstak v2 как отдельную платформу без временных мостов к первой версии.
- [07_Full_Implementation_Roadmap.md](07_Full_Implementation_Roadmap.md) - порядок доведения Verstak2 до полной standalone-реализации.
- [AGENTS.md](AGENTS.md) - инструкция для coding agents, чтобы они не возвращали проект к монолиту.

## Главный архитектурный инвариант

Core не знает о конкретных функциях вроде "заметки", "файловый менеджер" или "markdown editor". Core знает о:

- vault;
- plugin runtime;
- capability registry;
- contribution points;
- permissions;
- settings registry;
- event bus;
- storage API;
- UI shell.

Все рабочие инструменты поставляются плагинами. Даже официальные плагины должны жить по тем же правилам, что и будущие сторонние.

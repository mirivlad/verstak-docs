<div align="center">

# Verstak Platform Docs

### Architecture and platform documentation for Verstak.

**English** · [Русский](README.ru.md)

</div>

# Platform Architecture Reference

Architecture artifacts for the Verstak platform.

> Each executable component's build instructions live in its own README:
> Desktop, official plugins, browser extension and SDK must be built from
> the same release line.

## Contents

- [Product Vision](01_Product_Vision.md) — what stays unchanged
- [Platform Architecture](02_Platform_Architecture.md) — core design
- [Repositories](03_Repositories.md) — repository layout
- [Plugin System](04_Plugin_System.md) — dynamic plugins
- [Official Plugins](05_Official_Plugins.md) — plugin set and current status
- [Development Strategy](06_Migration_Strategy.md) — platform evolution
- [Implementation Roadmap](07_Full_Implementation_Roadmap.md) — full roadmap with phase status

The current official set includes a review-first DokuWiki and Obsidian importer:
it analyzes a selected folder or supported archive, proposes an editable
structure, and publishes only the confirmed plan under `Импортировано`.

## SDK Schemas

Data schemas and SDK contracts live in the
[`verstak-sdk`](https://github.com/mirivlad/verstak-sdk) repository.

- [Manifest Schema](https://github.com/mirivlad/verstak-sdk/blob/main/schemas/manifest.json)
- [Capabilities](https://github.com/mirivlad/verstak-sdk/blob/main/schemas/capabilities.json)
- [Contributions](https://github.com/mirivlad/verstak-sdk/blob/main/schemas/contributions.json)
- [Permissions](https://github.com/mirivlad/verstak-sdk/blob/main/schemas/permissions.json)
- [Event Schemas](https://github.com/mirivlad/verstak-sdk/tree/main/schemas/events)
- [Sync Operations](https://github.com/mirivlad/verstak-sdk/blob/main/schemas/sync.json)

## Repositories

| Repository | Purpose |
|---|---|
| [`verstak`](https://github.com/mirivlad/verstak) | Core Platform + UI Shell |
| [`verstak-official-plugins`](https://github.com/mirivlad/verstak-official-plugins) | Official plugins |
| [`verstak-sdk`](https://github.com/mirivlad/verstak-sdk) | Plugin SDK and schemas |
| [`verstak-sync-server`](https://github.com/mirivlad/verstak-sync-server) | Sync server |
| [`verstak-browser-extension`](https://github.com/mirivlad/verstak-browser-extension) | Browser extension |
| [`verstak-docs`](https://github.com/mirivlad/verstak-docs) | Documentation |

## License

Copyright © 2026 Verstak contributors. Documentation is licensed under
[GNU AGPLv3 or later](LICENSE).

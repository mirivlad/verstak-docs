# Platform Localization Design

## Context

Verstak v2 currently renders most desktop shell and official plugin text in
English. Application settings do not store a language, the frontend plugin API
has no localization contract, and plugin manifests expose only literal English
metadata. The sync server already has separate Russian and English catalogs and
is outside the scope of this desktop milestone. The browser extension also has
its own lifecycle and is explicitly deferred to a later milestone.

The first localization milestone covers:

- the `verstak-desktop` shell and core-owned screens;
- every plugin in `verstak-official-plugins`, including `platform-test`;
- the public SDK and manifest contract required by future third-party plugins;
- Russian and English;
- a persisted language selector in the desktop settings menu.

The existing `~/git/verstak` project remains a visual reference only. Its code
and localization architecture are not inputs to this implementation.

## Product Decisions

- The stored language preference is `system`, `ru`, or `en`.
- A new installation defaults to `system`.
- System locales beginning with `ru` resolve to Russian; all other system
  locales resolve to English.
- The settings menu offers System, Russian, and English choices.
- Changing the preference updates the running UI without restarting the app.
- The preference is installation-local and is not stored in or synchronized
  with a vault.
- Browser extension localization is a separate follow-up.
- Sync server localization remains independent from the desktop preference.

## Alternatives Considered

### Recommended: platform contract with plugin-owned catalogs

The shell owns shell translations. Each plugin owns its catalogs and declares
them in its manifest. The public plugin API exposes the resolved locale,
translation, and locale-change subscription.

Trade-offs:

- preserves repository and plugin ownership boundaries;
- gives third-party plugins the same mechanism as official plugins;
- requires coordinated SDK, desktop, manifest, and plugin changes;
- avoids teaching desktop core the UI vocabulary of official plugins.

### One desktop-wide catalog

Desktop would contain translations for shell and all official plugins.

Trade-offs:

- initially faster;
- couples core releases to plugin text and IDs;
- prevents independently distributed plugins from owning their localization;
- contradicts the dynamic plugin architecture.

### Independent dictionaries without a platform API

Every plugin would read a global value or DOM event and implement translation
on its own.

Trade-offs:

- small initial runtime change;
- inconsistent fallback and interpolation behavior;
- no stable SDK contract for third-party plugins;
- makes live locale changes and manifest metadata unreliable.

## Chosen Architecture

Use the platform contract with plugin-owned catalogs.

Localization is a UI platform service, not a user feature plugin. Desktop owns
language preference resolution, catalog loading, shell translation, and the
generic runtime bridge. It does not own plugin message content.

The data flow is:

```text
app config language preference
        |
        v
desktop locale store -----> shell catalogs
        |
        +------------------> localized manifest contributions
        |
        +------------------> api.i18n for each plugin
                                  |
                                  v
                         plugin-owned catalogs
```

## Application Setting

Add `Language string` to the desktop application config and expose it as
`language` through `GetAppSettings` and `UpdateAppSettings`.

Accepted persisted values:

```text
system
ru
en
```

Rules:

- missing or empty values load as `system`;
- unknown values are rejected by the update API and never persisted;
- an existing config requires no schema migration beyond applying the missing
  default;
- updating language must not reset `devMode`, theme, workbench preferences, or
  other unrelated settings;
- `system` is resolved in the frontend from `navigator.languages` or
  `navigator.language`, with `en` as the safe fallback.

The settings menu renders language names in their own language so the user can
recover from an accidental switch:

```text
System / Системный
English
Русский
```

The active option is visibly marked and uses menu radio semantics.

## Desktop Localization Service

Add one small frontend localization module that owns:

- the stored preference;
- the resolved locale (`ru` or `en`);
- the English and Russian shell catalogs;
- loaded plugin catalogs keyed by plugin ID and locale;
- a subscription API for Svelte shell components and plugin bridges;
- named parameter interpolation.

The shell-facing API is synchronous after initialization:

```js
getLanguagePreference()
getLocale()
t(key, params?, fallback?)
setLanguagePreference(preference)
subscribe(listener)
loadPluginCatalog(pluginId, localizationConfig)
translatePlugin(pluginId, key, params?, fallback?)
```

Application startup loads the persisted preference before the main interactive
shell is shown. Catalog-loading failures do not prevent startup.

Parameter interpolation supports named placeholders such as `{count}`. Missing
parameters leave the placeholder visible so catalog mistakes are detectable.
Catalog strings are always assigned through existing safe text rendering APIs;
translation values are not treated as HTML.

## Plugin Manifest Contract

Add an optional top-level manifest field:

```json
{
  "localization": {
    "defaultLocale": "en",
    "locales": {
      "en": "locales/en.json",
      "ru": "locales/ru.json"
    }
  }
}
```

The field belongs at the top level because manifest metadata and contributions
can be localized even when a plugin has no frontend bundle.

Validation rules:

- `defaultLocale` and locale map keys use lower-case supported locale tags;
- the default locale must have a declared catalog;
- catalog paths must be plugin-relative safe paths;
- absolute paths, traversal, backslashes, and paths outside the plugin root are
  rejected;
- localization is optional, preserving compatibility with existing and
  third-party plugins.

Catalog files are flat JSON string maps. Official plugins provide both `en`
and `ru` catalogs. The English manifest literals stay in place as readable
fallbacks and for compatibility with hosts that do not implement localization.

## Manifest And Contribution Keys

Desktop derives stable keys rather than embedding translation tokens in fields.

Reserved keys:

```text
manifest.name
manifest.description
contributions.views.<id>.title
contributions.commands.<id>.title
contributions.settingsPanels.<id>.title
contributions.sidebarItems.<id>.title
contributions.fileActions.<id>.title
contributions.noteActions.<id>.title
contributions.contextMenuEntries.<id>.title
contributions.searchProviders.<id>.label
contributions.statusBarItems.<id>.label
contributions.workspaceItems.<id>.title
```

The complete set follows contribution fields defined by the SDK schema. IDs
are used verbatim after the contribution type prefix. Missing keys retain the
literal manifest value.

The desktop localizes copies returned to frontend presentation code; it does
not mutate the backend registry or change IDs, handlers, capabilities, or
permission logic.

## Plugin Runtime API

Extend `VerstakPluginAPI` with:

```ts
i18n: {
  getLocale(): 'ru' | 'en';
  t(key: string, params?: Record<string, string | number>, fallback?: string): string;
  onDidChangeLocale(listener: (locale: 'ru' | 'en') => void): Unsubscribe;
}
```

The desktop preloads a plugin catalog before mounting its component. `t` is
therefore synchronous during rendering. The API automatically disposes locale
subscriptions with the rest of the plugin API.

Official plugin components subscribe once when mounted and rerender only their
text when the locale changes. Locale changes must not clear form values,
selection, dirty editor state, loaded data, or navigation state. The host does
not solve localization by unmounting and remounting plugin components.

Plugins without localization metadata continue to work. Their `t` calls return
the supplied fallback or key, and their literal manifest metadata remains
visible.

## Catalog Loading Boundary

Desktop exposes a dedicated read-only backend method for a declared plugin
catalog. It locates the enabled/discovered plugin, selects only a path declared
by its localization manifest, validates containment within the plugin root, and
returns a parsed string map or an error.

Do not repurpose arbitrary plugin settings or make localization catalogs
writable at runtime. Do not give plugins access to another plugin's catalog.

Catalog errors are isolated:

- malformed selected-locale catalog: fall back to default locale;
- missing default catalog: use manifest literals and key/fallback values;
- one broken plugin catalog: report a diagnostic without affecting other
  plugins or the shell.

## Fallback Rules

Shell translation fallback:

```text
resolved locale -> English catalog -> explicit fallback -> key
```

Plugin translation fallback:

```text
resolved locale -> plugin default locale -> explicit fallback -> key
```

Manifest/contribution fallback:

```text
resolved locale -> plugin default locale -> original manifest literal
```

Russian and English catalogs must have the same keys in CI for the shell and
official plugins. Third-party plugins may provide only their default locale.

## Scope Of Translated UI

The first milestone translates:

- vault onboarding and shell navigation;
- status bar, settings menu, command palette, global search chrome, dialogs,
  plugin host states, and Plugin Manager;
- all normal, empty, loading, confirmation, warning, and known validation
  states in official plugins;
- official plugin names, descriptions, contribution titles, and labels;
- accessibility labels and tooltips owned by shell or official plugins.

Arbitrary backend, operating-system, filesystem, network, and third-party error
messages remain in their source language. The surrounding user-facing prefix
and recovery instruction are translated. Stable known error codes may receive
localized messages in later milestones.

User data, filenames, workspace names, provider values, logs, identifiers, API
names, and developer diagnostics are never translated.

## Testing Strategy

Use TDD for each production change.

### SDK

- manifest schema accepts valid localization declarations;
- schema rejects unsafe or incomplete declarations;
- TypeScript types expose localization metadata and `api.i18n`;
- mock API implements locale reads, translations, and subscriptions;
- interpolation and fallback behavior are covered.

### Desktop backend

- missing language defaults to `system`;
- all three accepted values persist and reload;
- invalid values are rejected;
- language updates preserve unrelated settings;
- catalog reads accept only declared safe paths;
- malformed, missing, and traversal catalog cases fail safely.

### Desktop frontend

- system locale resolution maps `ru-*` to `ru` and others to `en`;
- shell fallback and interpolation are deterministic;
- language menu shows and persists the selected option;
- changing language updates visible shell text without reload;
- plugin API receives the locale and a working catalog;
- contribution labels change without changing contribution identity;
- missing plugin catalogs preserve English manifest literals.

### Official plugins

- every official manifest declares English and Russian catalogs;
- catalog key parity is checked;
- every manifest/contribution localization key is present;
- focused smoke tests exercise English and Russian rendering;
- a mounted component reacts to a locale change without losing its state.

### End-to-end

- first launch with a mocked Russian system locale renders Russian;
- first launch with another locale renders English;
- English -> Russian -> System selection persists through reload;
- shell and representative plain-JS and Svelte plugins switch together;
- plugin enable/disable and failed-plugin isolation still work.

## Rollout Order

1. SDK manifest/types/mock contract.
2. Desktop setting and catalog security boundary.
3. Desktop localization service and language menu.
4. Desktop shell catalog migration.
5. Official plugin manifests, catalogs, and runtime UI migration.
6. Full unit, smoke, build, and mocked-Wails E2E verification.
7. Real Wails/WebKit GUI smoke when the native environment is available.

The work remains split into small commits per repository. Existing unrelated
changes, including generated Wails bindings already present in the desktop
worktree, must not be included.

## Follow-up Work

After this localization milestone:

1. add browser-extension `_locales` catalogs and its independent language
   behavior;
2. introduce stable workspace IDs so renames do not orphan plugin scopes;
3. scope sync blobs by tenant/vault and make operation-sequence writes
   transactional;
4. make concurrent settings updates lossless;
5. remove remaining hard-coded official plugin IDs and schemas from shell;
6. reduce drift between E2E mock bundles and real plugin packages;
7. include whole-workspace entries in global Trash where appropriate.

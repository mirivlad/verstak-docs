# Browser Inbox Create Note Conversion Design

## Purpose

Browser Inbox should turn a captured page, selection, or link into useful vault
material without knowing Notes internals. This first conversion slice creates an
ordinary Markdown note through the public Files API.

## Scope

This slice adds one conversion action inside `verstak.browser-inbox`:

- render `Create Note` for captures that have a `workspaceRootPath`;
- write a Markdown file to `<workspaceRootPath>/Notes/<safe-title>.md` using
  `api.files.writeText`;
- publish `browser.capture.converted` after a successful write;
- remove the converted capture from the inbox queue;
- leave the capture in place and show an error if the write fails.

It does not add a separate Notes plugin API, link entity model, file attachment
conversion, bulk conversion, or Activity/Journal-specific UI. Other plugins can
react to the published conversion event through the public event bus.

## Note Path And Content

The generated note filename is a human-readable safe projection of the capture
title:

1. Prefer capture `title`.
2. Fall back to capture `domain`.
3. Fall back to capture `captureId`.
4. Replace unsafe filename characters with `_`.
5. Append `.md`.

The plugin writes with:

```js
api.files.writeText(notePath, markdown, {
  createIfMissing: true,
  overwrite: false
})
```

This preserves explicit conflict behavior. The plugin must not silently append a
suffix when a note already exists.

Markdown content:

```md
# <title>

Source: <url>
Captured: <capturedAt>
Kind: <kind>

<captured text when present>
```

Missing URL or text sections are omitted.

## Event Contract

After a successful conversion the plugin publishes:

```js
api.events.publish('browser.capture.converted', {
  captureId,
  conversionType: 'note',
  notePath,
  workspaceRootPath,
  title,
  url,
  sourcePluginId: 'verstak.browser-inbox'
})
```

The event is informational. Browser Inbox does not require Activity to be
installed and does not directly call Activity, Notes, Journal, or Search.

## Permissions

`verstak.browser-inbox` must add:

- `files.write`;
- `events.publish`.

Existing permissions remain unchanged.

## Testing

`scripts/smoke-browser-inbox-plugin.js` must prove:

- a workspace capture renders `Create Note`;
- clicking it writes the Markdown note through `api.files.writeText`;
- the write uses `createIfMissing: true` and `overwrite: false`;
- the capture is removed from its queue after success;
- `browser.capture.converted` is published with `conversionType: "note"`;
- when the write rejects, the capture remains in the queue and an error status
  is rendered.

# Browser Inbox Create Link Conversion Design

## Purpose

Browser captures should be convertible into a lightweight link artifact without
forcing every URL into Notes. This slice adds a public Files API conversion that
creates an ordinary human-readable `.url` file in the workspace.

## Scope

This slice adds one conversion action inside `verstak.browser-inbox`:

- render `Create Link` for captures that have both `workspaceRootPath` and a
  URL;
- write a `.url` shortcut file to `<workspaceRootPath>/Links/<safe-title>.url`
  through `api.files.writeText`;
- publish `browser.capture.converted` with `conversionType: "link"`;
- remove the converted capture from the inbox queue after a successful write;
- leave the capture in place and show an error if the write fails.

It does not add a core link entity model, a link resolver plugin, bulk
conversion, or file attachment capture.

## Link File Format

The generated file is a plain text Internet shortcut:

```ini
[InternetShortcut]
URL=https://example.com/article
```

The plugin writes with:

```js
api.files.writeText(linkPath, content, {
  createIfMissing: true,
  overwrite: false
})
```

This preserves explicit conflict behavior. The plugin must not silently append a
suffix when a link file already exists.

## Event Contract

After a successful conversion the plugin publishes:

```js
api.events.publish('browser.capture.converted', {
  captureId,
  conversionType: 'link',
  linkPath,
  workspaceRootPath,
  title,
  url,
  sourcePluginId: 'verstak.browser-inbox'
})
```

Activity can record this through the already-supported
`browser.capture.converted` event.

## Testing

`scripts/smoke-browser-inbox-plugin.js` must prove:

- a workspace capture with a URL renders `Create Link`;
- clicking it writes the `.url` file through `api.files.writeText`;
- the write uses `createIfMissing: true` and `overwrite: false`;
- the capture is removed from its queue after success;
- `browser.capture.converted` is published with `conversionType: "link"`;
- when the write rejects, the capture remains in the queue and an error status
  is rendered.

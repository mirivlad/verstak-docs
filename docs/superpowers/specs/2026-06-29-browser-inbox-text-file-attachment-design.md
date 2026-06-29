# Browser Inbox Text File Attachment Design

## Purpose

Browser Inbox needs a first file attachment path that uses the current public
plugin API instead of adding a private core inbox or binary write shortcut. This
slice supports text file attachments end to end: the browser extension reads a
user-selected text file, the local receiver publishes a `browser.capture.file`
event, and Browser Inbox converts the capture into an ordinary workspace file
through `api.files.writeText`.

Binary attachments remain out of scope until the platform has an explicit
public binary write API.

## Scope

This slice adds:

- extension protocol support for `kind: "file"`;
- popup file selection for text files;
- local receiver validation and event publication for file captures;
- Browser Inbox storage/rendering of file metadata and text content;
- a `Create File` conversion action for workspace-scoped text file captures.

It does not add drag-and-drop from web pages, screenshot capture, native download
interception, binary files, folders, or a core `.verstak/inbox` staging area.

## Capture Contract

The extension sends schema version 1 with a new file object:

```json
{
  "schemaVersion": 1,
  "captureId": "generated-id",
  "capturedAt": "2026-06-29T00:00:00.000Z",
  "source": "verstak-browser-extension",
  "kind": "file",
  "page": {
    "url": "https://example.com/current-page",
    "title": "Current page",
    "domain": "example.com"
  },
  "file": {
    "name": "notes.txt",
    "mime": "text/plain",
    "size": 120,
    "text": "file contents"
  },
  "browser": {
    "name": "Firefox"
  }
}
```

`file.name` and `file.text` are required for `kind: "file"`. The extension
limits text content to 2 MB so it stays within the current Files API text-read
size and avoids turning local receiver events into large binary transport.

## Receiver Event

The desktop receiver accepts `kind: "file"` and publishes
`browser.capture.file`. The event payload flattens file fields for Browser Inbox:

```js
{
  captureId,
  capturedAt,
  source,
  kind: 'file',
  url,
  title,
  domain,
  fileName,
  fileMime,
  fileSize,
  fileText,
  browserName
}
```

Current workspace annotation continues to work the same as page, selection, and
link captures.

## Browser Inbox Conversion

Browser Inbox subscribes to `browser.capture.file` and stores file fields in its
plugin-owned queue. In a workspace view, file captures render a `Create File`
action.

On success:

- write `<workspaceRootPath>/Files/<safe-file-name>` through
  `api.files.writeText`;
- use `{ createIfMissing: true, overwrite: false }`;
- publish `browser.capture.converted` with `conversionType: "file"` and
  `filePath`;
- remove the capture from the queue.

On write failure, Browser Inbox leaves the capture in the queue and renders an
error status.

## Testing

Required checks:

- browser extension protocol test builds and validates `kind: "file"`;
- receiver unit test accepts a file capture and publishes
  `browser.capture.file`;
- Browser Inbox smoke test verifies `Create File` write path, content, write
  options, queue removal, converted event, and failure behavior;
- full repo checks continue to pass for touched repositories.

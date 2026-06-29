# Binary File Write And Browser Attachments Design

## Purpose

Browser Inbox still cannot complete binary file attachment conversion because
the public Files API can read bounded bytes but cannot write them. This slice
adds a bounded public `files.writeBytes` contract and uses it to convert browser
file captures that contain base64 data.

The goal is not streaming or large-file import. It is a safe, testable binary
write path for small attachments that keeps plugins on public APIs.

## Scope

This slice adds:

- `api.files.writeBytes(relativePath, dataBase64, options)` for enabled plugins
  with `files.write`;
- desktop service support for atomic bounded byte writes up to 8 MB;
- sync op payload support for `dataBase64`, while preserving older text
  `content` payloads;
- SDK type/mock/test coverage for `files.writeBytes`;
- browser extension file capture that sends `file.dataBase64` for all selected
  files up to 8 MB and keeps `file.text` only for text-compatible files;
- local receiver flattening of `fileDataBase64`;
- Browser Inbox conversion that prefers `api.files.writeBytes` when binary data
  is present and falls back to `api.files.writeText` for text-only captures.

It does not add chunked streaming, folders, drag-and-drop from pages, download
interception, or binary preview changes.

## Files API Contract

`files.writeBytes(relativePath, dataBase64, options)`:

- accepts canonical vault-relative slash paths;
- rejects traversal, absolute paths, `.verstak`, symlinks, folders, missing
  parents, and conflicts using the same path policy as `writeText`;
- rejects invalid base64;
- rejects decoded payloads over `MaxBinaryReadBytes` (8 MB);
- writes atomically through a temp file in the target directory;
- requires `files.write`;
- records the same `file.changed` activity shape as text writes;
- records sync create/update payloads as `{ "path": "...", "dataBase64": "..." }`.

Remote sync apply supports both:

- old text payloads: `{ "path": "...", "content": "..." }`;
- new byte payloads: `{ "path": "...", "dataBase64": "..." }`.

## Browser Capture Contract

For `kind: "file"`, the extension sends:

```json
{
  "file": {
    "name": "photo.png",
    "mime": "image/png",
    "size": 1234,
    "dataBase64": "iVBORw0KGgo...",
    "text": ""
  }
}
```

`file.name` is required. A file capture is valid when either `file.dataBase64`
or `file.text` is present. The extension rejects selected files over 8 MB before
sending.

## Browser Inbox Conversion

Browser Inbox stores both `fileText` and `fileDataBase64`. `Create File` writes:

- `api.files.writeBytes(path, fileDataBase64, { createIfMissing: true,
  overwrite: false })` when binary data is present;
- otherwise `api.files.writeText(path, fileText, { createIfMissing: true,
  overwrite: false })`.

On success it publishes `browser.capture.converted` with
`conversionType: "file"` and removes the capture. On write failure it leaves the
capture in the queue and renders an error.

## Testing

Required checks:

- core Files service writes bytes, rejects invalid/oversized payloads, and
  preserves conflict/path behavior;
- desktop API bridge enforces `files.write`, records sync `dataBase64`, and
  applies remote binary payloads;
- frontend plugin API exposes `files.writeBytes`;
- SDK types and mock API include `writeBytes`;
- browser extension protocol builds, validates, and queues binary captures;
- receiver accepts file captures with `dataBase64`;
- Browser Inbox smoke proves binary conversion uses `writeBytes`;
- full verification scripts pass for touched repos.

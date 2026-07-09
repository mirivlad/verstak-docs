# Browser Receiver Pairing Design

## Purpose

The browser extension sends captures to the desktop local receiver with
`X-Verstak-Receiver-Token`. The desktop runtime starts that receiver only in
paired mode, without moving Browser Inbox queues or conversion behavior into
desktop core.

## Scope

This slice covers only the local receiver permission/pairing model:

- generation and local persistence of a receiver token;
- receiver token validation and rotation without a server restart;
- bounded capture payload validation before an event is published;
- Browser Inbox and extension settings for transferring the token.

It does not implement browser UI for pairing QR codes or encrypted keyring
storage. The current token is kept in the installation-local app settings file,
which the manager writes with mode `0600`.

## Model

The production receiver always starts in paired mode. On startup it generates a
32-byte random token when none exists, stores it outside the vault in
`~/.config/verstak/config.json`, and does not log it. If that token cannot be
persisted, the local receiver is disabled rather than opened without a token.
Every capture request must include:

```text
X-Verstak-Receiver-Token: <token>
```

The receiver compares the supplied token to the configured token using a
constant-time comparison. It does not publish browser capture events when the
token is missing or wrong. The package keeps the open constructor for embedded
legacy callers, but `main.go` does not use it.

## HTTP Contract

Endpoint:

```text
POST /api/browser-inbox/v1/captures
```

Successful capture:

```http
202 Accepted
```

```json
{ "status": "accepted", "captureId": "capture-id" }
```

Missing token in paired mode:

```http
401 Unauthorized
```

```json
{ "error": "receiver token required" }
```

Wrong token in paired mode:

```http
401 Unauthorized
```

```json
{ "error": "receiver token invalid" }
```

Other validation behavior remains unchanged: invalid payloads return `400`,
missing Browser Inbox consumers return `503`, and non-POST methods return
`405`. Payloads over 12 MiB return `413`; capture text, file metadata, encoded
binary data, and decoded file content are capped before publication.

## Runtime API

Desktop core exposes the model inside `internal/core/browserreceiver`:

```go
type Options struct {
    RequireToken  bool
    ReceiverToken string
}

func NewWithOptions(bus *events.Bus, options Options, providers ...WorkspaceProvider) *Receiver
```

`New(bus, providers...)` remains the open legacy constructor.

The Wails bridge exposes `PluginBrowserReceiverPairing` and
`PluginRotateBrowserReceiverToken` only to plugins declaring the dangerous
`browser.receiver.manage` permission. `verstak.browser-inbox` presents the
receiver URL, token copy action, and rotation control; the browser extension
stores the values in its local settings.

## Testing

`internal/core/browserreceiver/receiver_test.go` must prove:

- paired receivers reject missing tokens with `401`;
- paired receivers reject wrong tokens with `401`;
- paired receivers accept correct tokens and publish the capture event;
- a token persists across settings reload and changes immediately on rotation;
- oversized or malformed capture payloads do not publish an event;
- Browser Inbox and extension smoke tests cover the settings transfer path.

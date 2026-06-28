# Browser Receiver Pairing Design

## Purpose

The browser extension already sends captures to the desktop local receiver and
can include `X-Verstak-Receiver-Token`. The desktop receiver currently accepts
captures without a pairing model. This slice defines and implements the local
receiver token gate without moving Browser Inbox behavior into desktop core.

## Scope

This slice covers only the local receiver permission/pairing model:

- receiver token validation;
- clear HTTP responses for paired/unpaired requests;
- documentation of how the extension presents the token.

It does not implement domain-to-workspace binding, inbox conversion to
notes/files/activity, browser UI for pairing QR codes, or encrypted token
storage. Those remain later Phase 5 work.

## Model

The receiver has two modes:

- **Open legacy mode:** no receiver token is configured. This preserves current
  development behavior and accepts captures without the token header.
- **Paired mode:** a receiver token is configured and enabled. Every capture
  request must include:

```text
X-Verstak-Receiver-Token: <token>
```

The receiver compares the supplied token to the configured token using a
constant-time comparison. It does not publish browser capture events when the
token is missing or wrong.

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
`405`.

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

## Testing

`internal/core/browserreceiver/receiver_test.go` must prove:

- paired receivers reject missing tokens with `401`;
- paired receivers reject wrong tokens with `401`;
- paired receivers accept correct tokens and publish the capture event;
- open legacy receivers still accept captures without a token.

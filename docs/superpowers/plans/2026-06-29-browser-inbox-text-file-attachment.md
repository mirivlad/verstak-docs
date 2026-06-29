# Browser Inbox Text File Attachment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add end-to-end text file attachment capture and conversion through Browser Inbox.

**Architecture:** The browser extension remains a protocol producer and does not know workspace internals. Desktop receiver validates and republishes `browser.capture.file`; Browser Inbox stores the capture and writes the final text file through the public Files API.

**Tech Stack:** Plain JavaScript WebExtension code, Go receiver tests, official plugin JavaScript smoke harness, Markdown docs.

## Global Constraints

- Do not add private `.verstak/inbox` staging in this slice.
- Do not add binary file writes in this slice.
- Use only existing public plugin APIs for conversion: `api.files.writeText` and `api.events.publish`.
- Keep the extension offline queue behavior unchanged.
- Use TDD for each behavior change.

---

### Task 1: Extension Text File Capture Protocol

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-browser-extension/shared/protocol.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-browser-extension/shared/background.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-browser-extension/shared/popup/popup.html`
- Modify: `/home/mirivlad/git/verstak2/verstak-browser-extension/shared/popup/popup.css`
- Modify: `/home/mirivlad/git/verstak2/verstak-browser-extension/shared/popup/popup.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-browser-extension/scripts/test-protocol.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-browser-extension/README.md`

**Interfaces:**
- Produces `kind: "file"` capture payloads with `file.name`, `file.mime`,
  `file.size`, and `file.text`.

- [ ] **Step 1: Write RED protocol assertions**

Add a test that builds a file capture and asserts `validateCapture` accepts it,
then add a validation rejection for missing `file.text`.

- [ ] **Step 2: Run RED**

```bash
cd /home/mirivlad/git/verstak2/verstak-browser-extension
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH npm test
```

Expected: failure mentioning unsupported `kind` or missing file validation.

- [ ] **Step 3: Implement protocol and popup capture**

Add `file` payload support in `buildCapture` / `validateCapture`. Add a popup
file input and `Send File` button that reads one selected file as text and sends
`{ type: "verstak.capture", kind: "file", fileName, fileMime, fileSize, fileText }`.

- [ ] **Step 4: Run GREEN**

```bash
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH npm test
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH npm run build
```

Expected: protocol tests pass and extension dist builds.

### Task 2: Desktop Receiver File Event

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-desktop-current/internal/core/browserreceiver/receiver.go`
- Modify: `/home/mirivlad/git/verstak2/verstak-desktop-current/internal/core/browserreceiver/receiver_test.go`

**Interfaces:**
- Consumes extension `kind: "file"` payloads.
- Produces `browser.capture.file` events with flattened `fileName`,
  `fileMime`, `fileSize`, and `fileText`.

- [ ] **Step 1: Write RED receiver test**

Add a test that subscribes to `browser.capture.file`, posts a file capture, and
asserts the flattened event payload.

- [ ] **Step 2: Run RED**

```bash
cd /home/mirivlad/git/verstak2/verstak-desktop-current
go test ./internal/core/browserreceiver -run TestReceiverAcceptsFileCaptureAndPublishesEvent -count=1
```

Expected: failure with unsupported kind.

- [ ] **Step 3: Implement receiver support**

Add a `CaptureFile` struct, `File *CaptureFile` field, file validation, and
file payload flattening in `EventPayload`.

- [ ] **Step 4: Run GREEN**

```bash
go test ./internal/core/browserreceiver
./scripts/test.sh
```

Expected: receiver package and desktop script pass.

### Task 3: Browser Inbox Create File Conversion

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/plugins/browser-inbox/frontend/src/index.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/scripts/smoke-browser-inbox-plugin.js`

**Interfaces:**
- Consumes `browser.capture.file` events.
- Produces `Create File` action and `browser.capture.converted` with
  `conversionType: "file"`.

- [ ] **Step 1: Write RED smoke test**

Add success and failure scenarios for a workspace file capture. Assert the write
path `Project/Files/notes.txt`, file content, write options, queue removal, and
converted event.

- [ ] **Step 2: Run RED**

```bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH node scripts/smoke-browser-inbox-plugin.js
```

Expected: failure because `browser.capture.file` is not subscribed or
`Create File` is not rendered.

- [ ] **Step 3: Implement conversion**

Preserve `fileName`, `fileMime`, `fileSize`, and `fileText` in storage. Render a
`Create File` button for workspace file captures with text content. Write the
safe file path through `api.files.writeText`, publish the converted event, and
remove the capture on success.

- [ ] **Step 4: Run GREEN**

```bash
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH node scripts/smoke-browser-inbox-plugin.js
PATH=/tmp/verstak2-tools/venv/bin:/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH ./scripts/check.sh
```

Expected: browser inbox smoke and official plugin check pass.

### Task 4: Roadmap Documentation

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-docs/05_Official_Plugins.md`
- Modify: `/home/mirivlad/git/verstak2/verstak-docs/07_Full_Implementation_Roadmap.md`

**Interfaces:**
- Consumes verified file capture/conversion behavior.
- Produces roadmap language that marks text file attachment conversion complete
  while leaving binary attachments for a future public API slice.

- [ ] **Step 1: Update docs**

Describe Browser Inbox text file capture and conversion through the public Files
API.

- [ ] **Step 2: Verify docs**

```bash
cd /home/mirivlad/git/verstak2/verstak-docs
git diff --check
rg -n "text file attachment|binary attachment|browser.capture.file|Create File" 05_Official_Plugins.md 07_Full_Implementation_Roadmap.md docs/superpowers/specs/2026-06-29-browser-inbox-text-file-attachment-design.md docs/superpowers/plans/2026-06-29-browser-inbox-text-file-attachment.md
```

Expected: whitespace check exits 0 and `rg` shows updated status lines.

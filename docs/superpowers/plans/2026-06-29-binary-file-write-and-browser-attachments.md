# Binary File Write And Browser Attachments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add bounded binary file writes to the public Files API and use them for Browser Inbox binary attachment conversion.

**Architecture:** Desktop owns the safe byte-write primitive and sync payload compatibility. SDK and frontend bridge expose the method as public plugin API. Browser extension sends base64 for selected files, receiver republishes it, and Browser Inbox converts through `api.files.writeBytes`.

**Tech Stack:** Go Files service and Wails bridge, plain JavaScript plugin host and WebExtension code, TypeScript SDK types/tests, official plugin smoke harness, Markdown docs.

## Global Constraints

- Do not add chunked streaming in this slice.
- Do not allow plugins to write outside vault-relative path policy.
- Keep the write limit at 8 MB to match existing `readBytes`.
- Keep sync backward compatible with existing text `content` payloads.
- Use TDD for each behavior change.

---

### Task 1: Desktop Files API `writeBytes`

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-desktop-current/internal/core/files/service.go`
- Modify: `/home/mirivlad/git/verstak2/verstak-desktop-current/internal/core/files/service_test.go`
- Modify: `/home/mirivlad/git/verstak2/verstak-desktop-current/internal/api/app.go`
- Modify: `/home/mirivlad/git/verstak2/verstak-desktop-current/internal/api/app_test.go`
- Modify: `/home/mirivlad/git/verstak2/verstak-desktop-current/frontend/src/lib/plugin-host/VerstakPluginAPI.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-desktop-current/frontend/tests/plugin-api-files-test.mjs`
- Modify: `/home/mirivlad/git/verstak2/verstak-desktop-current/frontend/wailsjs/go/api/App.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-desktop-current/frontend/wailsjs/go/api/App.d.ts`

**Interfaces:**
- Produces `api.files.writeBytes(relativePath, dataBase64, options)`.
- Produces backend `WriteVaultFileBytes(pluginID, relativePath, dataBase64, options)`.

- [ ] **Step 1: Write RED service/API/bridge tests**

Add tests for successful byte write, invalid base64 rejection, oversized payload
rejection, permission enforcement, sync `dataBase64` payload, remote binary
apply, and frontend bridge exposure.

- [ ] **Step 2: Run RED**

```bash
cd /home/mirivlad/git/verstak2/verstak-desktop-current
go test ./internal/core/files -run TestWriteVaultFileBytesAtomicAndConflictBehavior -count=1
go test ./internal/api -run 'TestFilesBridgeReadWriteListMoveTrash|TestFilesBridgePermissions|TestApplyRemoteFileOps|TestFileBridgeRecordsSyncOps' -count=1
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH node frontend/tests/plugin-api-files-test.mjs
```

Expected: failures because `writeBytes` does not exist.

- [ ] **Step 3: Implement byte write**

Add atomic bounded base64 decode/write in the Files service, Wails bridge method,
plugin host method, generated Wails stubs, sync payload `DataBase64`, and remote
apply support.

- [ ] **Step 4: Run GREEN**

```bash
go test ./internal/core/files
go test ./internal/api
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH node frontend/tests/plugin-api-files-test.mjs
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH ./scripts/test.sh
```

Expected: all commands exit 0.

### Task 2: SDK `writeBytes` Contract

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-sdk/src/plugin-api.ts`
- Modify: `/home/mirivlad/git/verstak2/verstak-sdk/src/test-utils.ts`
- Modify: `/home/mirivlad/git/verstak2/verstak-sdk/src/plugin-api.test.ts`

**Interfaces:**
- Produces SDK `files.writeBytes(relativePath, dataBase64, options?)`.

- [ ] **Step 1: Write RED SDK test**

Assert `createMockPluginAPI().files.writeBytes` writes base64 content that can
be read back through `readBytes`.

- [ ] **Step 2: Run RED**

```bash
cd /home/mirivlad/git/verstak2/verstak-sdk
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH npm test
```

Expected: failure because `writeBytes` is missing.

- [ ] **Step 3: Implement SDK types and mock**

Add the method to `VerstakPluginAPI` and mock implementation.

- [ ] **Step 4: Run GREEN**

```bash
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH npm test
```

Expected: SDK tests pass.

### Task 3: Browser Extension Binary Capture

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-browser-extension/shared/protocol.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-browser-extension/shared/background.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-browser-extension/shared/popup/popup.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-browser-extension/scripts/test-protocol.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-browser-extension/README.md`

**Interfaces:**
- Produces file captures with `file.dataBase64` for selected files up to 8 MB.

- [ ] **Step 1: Write RED protocol test**

Add a binary file capture assertion and validate that missing both `file.text`
and `file.dataBase64` is rejected.

- [ ] **Step 2: Run RED**

```bash
cd /home/mirivlad/git/verstak2/verstak-browser-extension
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH npm test
```

Expected: failure because `dataBase64` is not preserved.

- [ ] **Step 3: Implement base64 file capture**

Read selected files as `ArrayBuffer`, base64 encode them, keep text only when
`file.text()` succeeds for text-like files, and enforce the 8 MB limit.

- [ ] **Step 4: Run GREEN**

```bash
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH npm test
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH npm run build
```

Expected: extension tests and build pass.

### Task 4: Receiver And Browser Inbox Binary Conversion

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-desktop-current/internal/core/browserreceiver/receiver.go`
- Modify: `/home/mirivlad/git/verstak2/verstak-desktop-current/internal/core/browserreceiver/receiver_test.go`
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/plugins/browser-inbox/frontend/src/index.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/scripts/smoke-browser-inbox-plugin.js`

**Interfaces:**
- Consumes `file.dataBase64`.
- Produces Browser Inbox conversion through `api.files.writeBytes`.

- [ ] **Step 1: Write RED tests**

Receiver test asserts `fileDataBase64`; Browser Inbox smoke asserts `Create File`
uses `writeBytes` for binary captures.

- [ ] **Step 2: Run RED**

```bash
cd /home/mirivlad/git/verstak2/verstak-desktop-current
go test ./internal/core/browserreceiver -run TestReceiverAcceptsFileCaptureAndPublishesEvent -count=1
cd /home/mirivlad/git/verstak2/verstak-official-plugins
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH node scripts/smoke-browser-inbox-plugin.js
```

Expected: failures for missing `fileDataBase64` and missing `writeBytes` path.

- [ ] **Step 3: Implement receiver and plugin conversion**

Add `DataBase64` to receiver file payload, preserve it in Browser Inbox storage,
and call `api.files.writeBytes` when present.

- [ ] **Step 4: Run GREEN**

```bash
cd /home/mirivlad/git/verstak2/verstak-desktop-current
go test ./internal/core/browserreceiver
cd /home/mirivlad/git/verstak2/verstak-official-plugins
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH node scripts/smoke-browser-inbox-plugin.js
PATH=/tmp/verstak2-tools/venv/bin:/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH ./scripts/check.sh
```

Expected: receiver and official plugin checks pass.

### Task 5: Documentation And Final Verification

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-docs/05_Official_Plugins.md`
- Modify: `/home/mirivlad/git/verstak2/verstak-docs/07_Full_Implementation_Roadmap.md`
- Modify: `/home/mirivlad/git/verstak2/verstak-desktop-current/docs/PLUGIN_RUNTIME.md`

**Interfaces:**
- Documents public `files.writeBytes` and binary Browser Inbox completion.

- [ ] **Step 1: Update docs**

Document `writeBytes`, base64/8 MB limits, sync compatibility, and mark binary
attachment conversion complete.

- [ ] **Step 2: Run full verification**

```bash
cd /home/mirivlad/git/verstak2/verstak-desktop-current && PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH ./scripts/test.sh
cd /home/mirivlad/git/verstak2/verstak-sdk && PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH npm test
cd /home/mirivlad/git/verstak2/verstak-browser-extension && PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH npm test && PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH npm run build
cd /home/mirivlad/git/verstak2/verstak-official-plugins && PATH=/tmp/verstak2-tools/venv/bin:/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH ./scripts/check.sh
cd /home/mirivlad/git/verstak2/verstak-docs && git diff --check
```

Expected: all commands exit 0.

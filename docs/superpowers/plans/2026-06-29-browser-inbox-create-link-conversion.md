# Browser Inbox Create Link Conversion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Browser Inbox conversion workflow that creates an ordinary `.url` link file from a captured URL.

**Architecture:** Keep conversion behavior in `verstak.browser-inbox`. The plugin writes a human-readable `.url` file through `api.files.writeText`, publishes `browser.capture.converted`, and leaves Activity/other consumers decoupled through the event bus.

**Tech Stack:** Plain JavaScript official plugin bundle, Node smoke test harness, Markdown docs.

## Global Constraints

- Do not add a core link entity model in this slice.
- Do not call private APIs from Browser Inbox.
- Use only public plugin APIs: `api.files.writeText` and `api.events.publish`.
- Do not silently rename on link path conflict; rely on `overwrite: false`.
- Use TDD: write the failing smoke test first, run it red, then implement.

---

### Task 1: Browser Inbox Create Link Conversion

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/scripts/smoke-browser-inbox-plugin.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/plugins/browser-inbox/frontend/src/index.js`

**Interfaces:**
- Consumes:
  - `api.files.writeText(relativePath, content, { createIfMissing: true, overwrite: false })`
  - `api.events.publish('browser.capture.converted', payload)`
- Produces:
  - `Create Link` action for workspace-scoped URL captures.
  - `browser.capture.converted` event with `conversionType: "link"`.

- [ ] **Step 1: Write the failing smoke test**

Add a scenario to `scripts/smoke-browser-inbox-plugin.js` that clicks
`data-browser-inbox-action="create-link"` and asserts the written path,
`.url` content, write options, queue removal, and published event.

- [ ] **Step 2: Run RED**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH node scripts/smoke-browser-inbox-plugin.js
```

Expected: fails because `Create Link` is not rendered.

- [ ] **Step 3: Implement conversion**

Add helpers in `plugins/browser-inbox/frontend/src/index.js`:

- `safeLinkFilename(title)`;
- `captureToUrlShortcut(capture)`;
- `createLinkFromCapture(capture)`.

Render a `Create Link` button for captures with `workspaceRootPath` and `url`.
On success, remove the capture and publish `browser.capture.converted`.

- [ ] **Step 4: Run GREEN**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH node scripts/smoke-browser-inbox-plugin.js
PATH=/tmp/verstak2-tools/venv/bin:/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH ./scripts/check.sh
```

Expected: both commands exit 0.

### Task 2: Roadmap Documentation

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-docs/05_Official_Plugins.md`
- Modify: `/home/mirivlad/git/verstak2/verstak-docs/07_Full_Implementation_Roadmap.md`

**Interfaces:**
- Consumes verified create-link conversion behavior.
- Produces docs that mark link file conversion done while leaving file attachment capture for later.

- [ ] **Step 1: Update docs**

Describe Browser Inbox create-link conversion through the public Files API and
mark link conversion as complete.

- [ ] **Step 2: Verify docs**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-docs
git diff --check
rg -n "Create Link|link conversion|file attachment|browser.capture.converted" 05_Official_Plugins.md 07_Full_Implementation_Roadmap.md
```

Expected: `git diff --check` exits 0 and `rg` shows updated status lines.

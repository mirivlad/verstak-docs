# Browser Inbox Create Note Conversion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first Browser Inbox conversion workflow that creates an ordinary Markdown note from a capture.

**Architecture:** Keep conversion behavior in `verstak.browser-inbox`. The plugin uses only public `api.files.writeText` and `api.events.publish`, removes the capture after a successful conversion, and leaves conversion consumers decoupled through the event bus.

**Tech Stack:** Plain JavaScript official plugin bundle, Node smoke test harness, plugin manifest permissions, Markdown docs.

## Global Constraints

- Do not move Browser Inbox conversion workflows into desktop core.
- Do not call Notes, Activity, Journal, or Search private APIs.
- Use only public plugin APIs: `api.files.writeText` and `api.events.publish`.
- Do not silently rename on note path conflict; rely on `overwrite: false`.
- Use TDD: write the failing smoke test first, run it red, then implement.

---

### Task 1: Browser Inbox Create Note Conversion

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/scripts/smoke-browser-inbox-plugin.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/plugins/browser-inbox/frontend/src/index.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/plugins/browser-inbox/plugin.json`

**Interfaces:**
- Consumes:
  - `api.files.writeText(relativePath, content, { createIfMissing: true, overwrite: false })`
  - `api.events.publish('browser.capture.converted', payload)`
- Produces:
  - `Create Note` action for workspace-scoped captures.
  - `browser.capture.converted` event after successful conversion.

- [ ] **Step 1: Write the failing smoke test**

Add fake API support for `files.writeText` and `events.publish` in
`scripts/smoke-browser-inbox-plugin.js`, then add a scenario that clicks
`data-browser-inbox-action="create-note"` and asserts the written path,
Markdown content, write options, queue removal, and published event.

- [ ] **Step 2: Run RED**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH node scripts/smoke-browser-inbox-plugin.js
```

Expected: fails because `Create Note` is not rendered.

- [ ] **Step 3: Implement conversion**

Add helpers in `plugins/browser-inbox/frontend/src/index.js`:

- `noteTitle(capture)`;
- `safeNoteFilename(title)`;
- `captureToMarkdown(capture)`;
- `createNoteFromCapture(capture)`.

Render a `Create Note` button for captures with a workspace root. On success,
remove the capture and publish `browser.capture.converted`.

- [ ] **Step 4: Update manifest permissions**

Add `files.write` and `events.publish` to
`plugins/browser-inbox/plugin.json`.

- [ ] **Step 5: Run GREEN**

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
- Consumes verified create-note conversion behavior.
- Produces docs that mark note conversion done while leaving link/file/activity conversion for later.

- [ ] **Step 1: Update docs**

Describe Browser Inbox create-note conversion through the public Files API and
mark only note conversion as complete.

- [ ] **Step 2: Verify docs**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-docs
git diff --check
rg -n "Create Note|note conversion|conversion workflow|notes/links/files/activity" 05_Official_Plugins.md 07_Full_Implementation_Roadmap.md
```

Expected: `git diff --check` exits 0 and `rg` shows updated status lines.

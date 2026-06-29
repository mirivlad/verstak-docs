# Browser Inbox Domain Binding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route unscoped Browser Inbox captures into workspace queues through plugin-owned domain bindings.

**Architecture:** Keep domain binding in `verstak.browser-inbox`. The plugin reads `domainBindings` from its own settings namespace, annotates unscoped incoming captures before storage, and preserves desktop core as a capture-event publisher only.

**Tech Stack:** Plain JavaScript official plugin bundle, Node smoke test harness, Markdown docs.

## Global Constraints

- Do not move Browser Inbox queues or conversion workflows into desktop core.
- Do not import Notes, Files, Activity, or Journal from Browser Inbox.
- Route only captures that do not already include `workspaceRootPath`.
- Domain matching is exact and case-insensitive for this slice.
- Use TDD: write the failing smoke test first, run it red, then implement.

---

### Task 1: Browser Inbox Domain Routing

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/scripts/smoke-browser-inbox-plugin.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/plugins/browser-inbox/frontend/src/index.js`

**Interfaces:**
- Consumes: Browser Inbox plugin settings key `domainBindings`.
- Produces: unscoped captures annotated with `workspaceRootPath` and `workspaceName` when an exact domain binding exists.

- [ ] **Step 1: Write the failing smoke test**

Add a scenario to `scripts/smoke-browser-inbox-plugin.js`:

```js
const bindingApi = makeApi({
  domainBindings: {
    'client.example.com': 'ClientA',
    'project.example.com': 'Project'
  }
});
const bindingGlobal = await mountWithApi(bindingApi, {});
await bindingApi.handlers['browser.capture.page']({
  name: 'browser.capture.page',
  timestamp: '2026-06-29T00:00:00Z',
  payload: {
    captureId: 'bound-client-capture',
    capturedAt: '2026-06-29T00:00:00.000Z',
    kind: 'page',
    url: 'https://client.example.com/page',
    title: 'Bound Client Page',
    domain: 'client.example.com'
  }
});
await flush();
if (bindingApi.getStoredCaptures('captures:workspace:ClientA').length !== 1) {
  throw new Error('domain-bound capture was not stored under ClientA workspace key');
}
```

Also prove explicit `workspaceRootPath: "Project"` wins over a binding for
`client.example.com`.

- [ ] **Step 2: Run RED**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH node scripts/smoke-browser-inbox-plugin.js
```

Expected: fails because domain-bound captures are still stored in the receiving
view scope.

- [ ] **Step 3: Implement minimal routing**

In `plugins/browser-inbox/frontend/src/index.js`, add helper functions to
normalize binding keys, derive a domain from capture fields, and annotate
captures without `workspaceRootPath` before storage.

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
- Consumes verified plugin routing behavior.
- Produces docs that distinguish implemented domain binding from future conversion workflows.

- [ ] **Step 1: Update docs**

Mark domain binding as implemented in the Browser Inbox status text and roadmap
while leaving conversion workflow as future work.

- [ ] **Step 2: Verify docs**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-docs
git diff --check
rg -n "domain-to-workspace binding|Domain binding|conversion" 05_Official_Plugins.md 07_Full_Implementation_Roadmap.md
```

Expected: `git diff --check` exits 0 and `rg` shows the updated status lines.

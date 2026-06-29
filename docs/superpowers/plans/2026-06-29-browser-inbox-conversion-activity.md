# Browser Inbox Conversion Activity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Record Browser Inbox note conversions in Activity through the public `browser.capture.converted` event.

**Architecture:** Keep plugins decoupled. Browser Inbox already publishes `browser.capture.converted`; Activity subscribes to that event through its normal frontend event list and manifest `activityProviders` contribution.

**Tech Stack:** Plain JavaScript official plugins, Node smoke test harness, plugin manifest, Markdown docs.

## Global Constraints

- Do not add a direct Browser Inbox to Activity API.
- Do not move conversion recording into desktop core.
- Use only public event subscription behavior.
- Use TDD: write the failing Activity smoke test first, run it red, then implement.

---

### Task 1: Activity Conversion Event Recording

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/scripts/smoke-activity-plugin.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/plugins/activity/frontend/src/index.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/plugins/activity/plugin.json`

**Interfaces:**
- Consumes: `browser.capture.converted` event payload from Browser Inbox.
- Produces: stored Activity entry using the existing activity event model.

- [ ] **Step 1: Write the failing smoke test**

In `scripts/smoke-activity-plugin.js`, add `browser.capture.converted` to the
required subscription checks and dispatch a workspace-scoped conversion event.
Assert it is stored, rendered, and included in worklog suggestion event ids.

- [ ] **Step 2: Run RED**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH node scripts/smoke-activity-plugin.js
```

Expected: fails because Activity does not subscribe to
`browser.capture.converted`.

- [ ] **Step 3: Implement event subscription**

Add `browser.capture.converted` to `ACTIVITY_EVENTS` in
`plugins/activity/frontend/src/index.js` and to
`contributes.activityProviders[0].events` in `plugins/activity/plugin.json`.

- [ ] **Step 4: Run GREEN**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins
PATH=/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH node scripts/smoke-activity-plugin.js
PATH=/tmp/verstak2-tools/venv/bin:/tmp/verstak2-tools:/home/mirivlad/.lmstudio/.internal/utils:$PATH ./scripts/check.sh
```

Expected: both commands exit 0.

### Task 2: Roadmap Documentation

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-docs/05_Official_Plugins.md`
- Modify: `/home/mirivlad/git/verstak2/verstak-docs/07_Full_Implementation_Roadmap.md`

**Interfaces:**
- Consumes verified Activity recording behavior.
- Produces docs that mark Activity integration for capture conversion complete.

- [ ] **Step 1: Update docs**

Describe that `browser.capture.converted` is recorded by Activity and that
link/file-specific conversions remain.

- [ ] **Step 2: Verify docs**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-docs
git diff --check
rg -n "browser.capture.converted|link/file" 05_Official_Plugins.md 07_Full_Implementation_Roadmap.md
```

Expected: `git diff --check` exits 0 and `rg` shows updated status lines.

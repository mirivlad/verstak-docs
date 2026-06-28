# Journal Worklog Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a baseline `verstak.journal` plugin that stores worklog entries and imports Activity worklog suggestions.

**Architecture:** Implement Journal as a plain official frontend plugin. Store entries in plugin settings by workspace key, render a workspace/global Journal view, and consume Activity suggestions through `api.commands.executeFor`.

**Tech Stack:** Official plugin JSON manifest, browserless JavaScript bundle, Node smoke test, Markdown docs.

## Global Constraints

- Journal/worklog remains plugin functionality, not desktop core.
- Do not build billing reports or invoice export in this slice.
- Import from Activity must degrade cleanly when Activity is unavailable.
- Use TDD: write and run a failing smoke test before creating the plugin.
- Commit and push each affected repository after meaningful changes.

---

### Task 1: Document The Slice

**Files:**
- Create: `/home/mirivlad/git/verstak2/verstak-docs/docs/superpowers/specs/2026-06-29-journal-worklog-plugin-design.md`
- Create: `/home/mirivlad/git/verstak2/verstak-docs/docs/superpowers/plans/2026-06-29-journal-worklog-plugin.md`

**Interfaces:**
- Produces a written contract for `verstak.journal`.

- [ ] **Step 1: Write spec and plan**

Write the design and this implementation plan.

- [ ] **Step 2: Verify docs**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-docs
git diff --check
```

Expected: exits 0.

- [ ] **Step 3: Commit and push docs**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-docs
git add docs/superpowers/specs/2026-06-29-journal-worklog-plugin-design.md docs/superpowers/plans/2026-06-29-journal-worklog-plugin.md
git commit -m "docs: plan journal worklog plugin"
git push
```

Expected: docs `main` is clean and pushed.

### Task 2: Journal Plugin

**Files:**
- Create: `/home/mirivlad/git/verstak2/verstak-official-plugins/plugins/journal/plugin.json`
- Create: `/home/mirivlad/git/verstak2/verstak-official-plugins/plugins/journal/frontend/src/index.js`
- Create: `/home/mirivlad/git/verstak2/verstak-official-plugins/scripts/smoke-journal-plugin.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/scripts/check.sh`

**Interfaces:**
- Produces plugin id `verstak.journal`.
- Produces component `JournalView`.
- Consumes `api.commands.executeFor('verstak.activity', 'verstak.activity.suggestWorklog', args)`.

- [ ] **Step 1: Write the failing smoke test**

Create `scripts/smoke-journal-plugin.js` and assert manifest identity,
mounting, manual entry storage, Activity import, duplicate prevention, and
global aggregation.

- [ ] **Step 2: Run RED**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins
node scripts/smoke-journal-plugin.js
```

Expected: fails because the Journal manifest and frontend entry do not exist.

- [ ] **Step 3: Add manifest and frontend**

Create `plugins/journal/plugin.json` with `provides` of `worklog`, `journal`,
and `report.worklog`, optional dependency `activity.reconstruction`, and
workspace/sidebar UI contributions. Create `JournalView` that stores entries
under `worklog:workspace:<encoded workspace root>`.

- [ ] **Step 4: Wire check script**

Add `node "$ROOT/scripts/smoke-journal-plugin.js"` to the frontend smoke
section in `scripts/check.sh`.

- [ ] **Step 5: Run GREEN**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins
node scripts/smoke-journal-plugin.js
./scripts/check.sh
```

Expected: both commands exit 0.

- [ ] **Step 6: Commit and push official plugin**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins
git add plugins/journal scripts/smoke-journal-plugin.js scripts/check.sh
git commit -m "feat: add journal worklog plugin"
git push
```

Expected: official plugins `main` is clean and pushed.

### Task 3: Mark Roadmap Progress

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-docs/05_Official_Plugins.md`
- Modify: `/home/mirivlad/git/verstak2/verstak-docs/07_Full_Implementation_Roadmap.md`

**Interfaces:**
- Consumes verified Journal plugin commit.
- Produces docs matching implemented behavior.

- [ ] **Step 1: Update Journal status**

Add a current status sentence describing the baseline Journal plugin, manual
worklog entries, and Activity suggestion import.

- [ ] **Step 2: Update roadmap**

Change:

```md
- implement journal/worklog plugin that can consume activity suggestions.
```

to:

```md
- [x] implement journal/worklog plugin that can consume activity suggestions.
```

- [ ] **Step 3: Verify docs**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-docs
git diff --check
rg -n "implement journal/worklog plugin that can consume activity suggestions|baseline `verstak.journal`" 05_Official_Plugins.md 07_Full_Implementation_Roadmap.md
```

Expected: `git diff --check` exits 0 and `rg` shows the checked roadmap line
and Journal status.

- [ ] **Step 4: Commit and push docs**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-docs
git add 05_Official_Plugins.md 07_Full_Implementation_Roadmap.md
git commit -m "docs: mark journal worklog plugin complete"
git push
```

Expected: docs `main` is clean and pushed.

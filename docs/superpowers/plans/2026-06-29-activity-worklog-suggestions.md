# Activity Worklog Suggestions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a minimal Activity reconstruction layer that renders and exposes worklog suggestions from recorded activity events.

**Architecture:** Keep reconstruction inside `verstak.activity`. Generate suggestions from normalized stored events, render them in the Activity view, and expose them through a command-backed runtime contract for the future Journal plugin.

**Tech Stack:** Official plugin browserless JavaScript bundle, Node smoke tests, JSON plugin manifest, Markdown docs.

## Global Constraints

- Do not move activity or journal logic into desktop core.
- Do not build the Journal plugin in this slice.
- Suggestions are derived from existing Activity events and are informational.
- Use TDD: update the activity smoke test first, run it red, then implement.
- Commit and push each affected repository after meaningful changes.

---

### Task 1: Document The Slice

**Files:**
- Create: `/home/mirivlad/git/verstak2/verstak-docs/docs/superpowers/specs/2026-06-29-activity-worklog-suggestions-design.md`
- Create: `/home/mirivlad/git/verstak2/verstak-docs/docs/superpowers/plans/2026-06-29-activity-worklog-suggestions.md`

**Interfaces:**
- Produces: written contract for `verstak.activity.suggestWorklog`.

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
git add docs/superpowers/specs/2026-06-29-activity-worklog-suggestions-design.md docs/superpowers/plans/2026-06-29-activity-worklog-suggestions.md
git commit -m "docs: plan activity worklog suggestions"
git push
```

Expected: docs `main` is clean and pushed.

### Task 2: Activity Suggestions Runtime

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/plugins/activity/plugin.json`
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/plugins/activity/frontend/src/index.js`
- Modify: `/home/mirivlad/git/verstak2/verstak-official-plugins/scripts/smoke-activity-plugin.js`

**Interfaces:**
- Produces command: `verstak.activity.suggestWorklog(args?: { workspaceRootPath?: string }): Promise<{ suggestions: WorklogSuggestion[] }>`
- Produces DOM: `data-activity-section="worklog-suggestions"` and `data-worklog-suggestion="<suggestionId>"`

- [ ] **Step 1: Write the failing smoke assertions**

Extend `scripts/smoke-activity-plugin.js` to read the Activity manifest, mock
`api.commands.register`, and assert that:

- `commands.register` permission exists;
- command contribution `verstak.activity.suggestWorklog` exists;
- the command is registered after mount;
- Project events render a suggestion;
- executing the command returns a suggestion with `minutes`, `summary`, and
  source `eventIds`;
- global Activity renders separate Project and ClientA suggestions;
- clear removes the rendered suggestion.

- [ ] **Step 2: Run RED**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins
node scripts/smoke-activity-plugin.js
```

Expected: fails because `verstak.activity.suggestWorklog` is not registered.

- [ ] **Step 3: Update manifest**

Add `commands.register` to permissions and add:

```json
{
  "id": "verstak.activity.suggestWorklog",
  "title": "Suggest Worklog From Activity",
  "handler": "verstak.activity.suggestWorklog"
}
```

under `contributes.commands`.

- [ ] **Step 4: Implement suggestions**

In `plugins/activity/frontend/src/index.js`:

- define `WORKLOG_COMMAND_ID = 'verstak.activity.suggestWorklog'`;
- add `suggestions` state;
- derive suggestions from normalized events grouped by workspace/day;
- render a suggestions band above the activity list;
- register the command with `api.commands.register`;
- recompute suggestions after load, event refresh, and clear.

- [ ] **Step 5: Run GREEN**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins
node scripts/smoke-activity-plugin.js
./scripts/check.sh
```

Expected: both commands exit 0.

- [ ] **Step 6: Commit and push official plugin**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-official-plugins
git add plugins/activity/plugin.json plugins/activity/frontend/src/index.js scripts/smoke-activity-plugin.js
git commit -m "feat: suggest worklogs from activity"
git push
```

Expected: official plugins `main` is clean and pushed.

### Task 3: Mark Roadmap Progress

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-docs/05_Official_Plugins.md`
- Modify: `/home/mirivlad/git/verstak2/verstak-docs/07_Full_Implementation_Roadmap.md`

**Interfaces:**
- Consumes verified official plugin commit.
- Produces docs matching implemented behavior.

- [ ] **Step 1: Update Activity status**

Replace the sentence saying reconstruction/worklog suggestions are future work
with a sentence describing the implemented suggestion band and command.

- [ ] **Step 2: Update roadmap**

Change:

```md
- implement activity reconstruction and worklog suggestions;
```

to:

```md
- [x] implement activity reconstruction and worklog suggestions;
```

- [ ] **Step 3: Verify docs**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-docs
git diff --check
rg -n "Reconstruction and worklog suggestions are still future work|implement activity reconstruction and worklog suggestions" 05_Official_Plugins.md 07_Full_Implementation_Roadmap.md
```

Expected: `git diff --check` exits 0. `rg` shows only the checked roadmap line.

- [ ] **Step 4: Commit and push docs**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-docs
git add 05_Official_Plugins.md 07_Full_Implementation_Roadmap.md
git commit -m "docs: mark activity worklog suggestions complete"
git push
```

Expected: docs `main` is clean and pushed.

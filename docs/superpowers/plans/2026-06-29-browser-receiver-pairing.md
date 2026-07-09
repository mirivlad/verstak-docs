# Browser Receiver Pairing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a token-based pairing gate to the local browser capture receiver.

**Architecture:** Keep Browser Inbox as a plugin. The desktop runtime generates
and requires an installation-local receiver token, while the plugin and browser
extension expose the settings transfer and rotation flow.

**Tech Stack:** Go desktop core package tests, browser extension protocol docs, Markdown docs.

## Completion Status (2026-07-10)

Completed. The implementation also added bounded ingress validation, token
persistence and rotation, the `browser.receiver.manage` SDK permission, a
Browser Inbox settings panel, and extension popup token persistence.

## Global Constraints

- Do not move Browser Inbox queues or conversion workflows into desktop core.
- Production startup must fail closed when a token cannot be persisted.
- Paired mode must not publish capture events for missing or wrong tokens.
- Use TDD: write the failing Go receiver test first, run it red, then implement.
- Commit and push each affected repository after meaningful changes.

---

### Task 1: Document The Pairing Contract

**Files:**
- Create: `/home/mirivlad/git/verstak2/verstak-docs/docs/superpowers/specs/2026-06-29-browser-receiver-pairing-design.md`
- Create: `/home/mirivlad/git/verstak2/verstak-docs/docs/superpowers/plans/2026-06-29-browser-receiver-pairing.md`

**Interfaces:**
- Produces documented `X-Verstak-Receiver-Token` pairing contract.

- [x] **Step 1: Write spec and plan**

Write the design and this implementation plan.

- [x] **Step 2: Verify docs**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-docs
git diff --check
```

Expected: exits 0.

- [x] **Step 3: Commit and push docs**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-docs
git add docs/superpowers/specs/2026-06-29-browser-receiver-pairing-design.md docs/superpowers/plans/2026-06-29-browser-receiver-pairing.md
git commit -m "docs: plan browser receiver pairing"
git push
```

Expected: docs `main` is clean and pushed.

### Task 2: Desktop Receiver Token Gate

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-desktop/internal/core/browserreceiver/receiver_test.go`
- Modify: `/home/mirivlad/git/verstak2/verstak-desktop/internal/core/browserreceiver/receiver.go`

**Interfaces:**
- Produces:
  - `type Options struct { RequireToken bool; ReceiverToken string }`
  - `func NewWithOptions(bus *events.Bus, options Options, providers ...WorkspaceProvider) *Receiver`

- [x] **Step 1: Write the failing tests**

Add tests proving missing/wrong token rejection and correct token acceptance.

- [x] **Step 2: Run RED**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-desktop
go test ./internal/core/browserreceiver
```

Expected: fails because `Options` / `NewWithOptions` do not exist.

- [x] **Step 3: Implement token gate**

Add `Options`, `NewWithOptions`, header validation, and constant-time token
comparison. Keep `New` behavior unchanged.

- [x] **Step 4: Run GREEN**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-desktop
go test ./internal/core/browserreceiver
go test ./internal/core/...
```

Expected: both commands exit 0.

- [x] **Step 5: Commit and push desktop**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-desktop
git add internal/core/browserreceiver/receiver.go internal/core/browserreceiver/receiver_test.go
git commit -m "feat: require token for paired browser receiver"
git push
```

Expected: commit is pushed. Existing unrelated `frontend/wailsjs/go/models.ts`
remains unstaged.

### Task 3: Extension And Roadmap Docs

**Files:**
- Modify: `/home/mirivlad/git/verstak2/verstak-browser-extension/README.md`
- Modify: `/home/mirivlad/git/verstak2/verstak-docs/05_Official_Plugins.md`
- Modify: `/home/mirivlad/git/verstak2/verstak-docs/07_Full_Implementation_Roadmap.md`

**Interfaces:**
- Consumes verified receiver token gate.
- Produces docs matching implemented pairing behavior.

- [x] **Step 1: Update extension README**

Change the receiver token header description from optional future work to:

```md
- `X-Verstak-Receiver-Token: <token>` required when the desktop receiver is in paired mode
```

- [x] **Step 2: Verify and commit extension docs**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-browser-extension
git diff --check
git add README.md
git commit -m "docs: describe receiver token pairing"
git push
```

Expected: extension `main` is clean and pushed.

- [x] **Step 3: Update platform docs**

In `05_Official_Plugins.md`, describe that Browser Inbox receives captures
through the local receiver token pairing model. In
`07_Full_Implementation_Roadmap.md`, mark:

```md
- [x] define local receiver permission/pairing model;
```

- [x] **Step 4: Verify and commit docs**

Run:

```bash
cd /home/mirivlad/git/verstak2/verstak-docs
git diff --check
rg -n "define local receiver permission/pairing model|X-Verstak-Receiver-Token" 05_Official_Plugins.md 07_Full_Implementation_Roadmap.md
git add 05_Official_Plugins.md 07_Full_Implementation_Roadmap.md
git commit -m "docs: mark browser receiver pairing complete"
git push
```

Expected: docs `main` is clean and pushed.

# Alpha Browser Domain Activity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Add explicitly consented, privacy-minimal active-tab domain timing to the browser extension and deliver immutable activity batches to Desktop.

**Architecture:** Manual captures remain unchanged. A new tracker stores mutable accumulators, immutable pending batches, and acknowledged IDs locally; Desktop accepts a separate authenticated activity endpoint and emits browser.activity.domain.

**Tech Stack:** Plain WebExtension JavaScript, Node tests, Go HTTP handler tests, shared JSON vectors.

## Global Constraints

- Passive tracking defaults to disabled and requires explicit informed consent.
- Track only normalized hostname plus duration for an active tab in a focused window.
- Never send URL, title, text, page content, keystrokes, or history.
- A pending batch is byte-for-byte immutable; acknowledge only its own ID.
- Discard ambiguous or negative clock deltas and gaps over 10 minutes.
- Use hostname-normalization-v1 for extension, Desktop receiver, exclusions, and bindings.

---

### Task 1: Define and test canonical hostname normalization

**Files:**
- Create: /home/mirivlad/git/verstak2/verstak-sdk/schemas/hostname-normalization-v1.json
- Create: /home/mirivlad/git/verstak2/verstak-browser-extension/shared/hostname.js
- Create: /home/mirivlad/git/verstak2/verstak-browser-extension/shared/hostname-normalization-v1.json
- Create: /home/mirivlad/git/verstak2/verstak-browser-extension/scripts/test-hostname.js
- Create: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/hostname/normalize.go
- Create: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/hostname/normalize_test.go
- Create: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/hostname/testdata/hostname-normalization-v1.json

**Interfaces:**
- Produces JavaScript normalizeHostnameV1(value, mode).
- Produces Go hostname.NormalizeV1(value string, mode Mode) (string, error).
- Mode is URLSource for HTTP(S) URLs and BareHost for binding/exclusion input.

- [ ] **Step 1: Write the shared vector corpus and failing tests**

Include vectors for Unicode/punycode, trailing dot, port stripping/rejection,
IPv4, bracketed IPv6, localhost, one-label internal names, malformed labels,
and an overlong name:

~~~json
[
  {"mode":"bare","input":"пример.рф.","want":"xn--e1afmkfd.xn--p1ai"},
  {"mode":"url","input":"https://Example.COM:8443/a","want":"example.com"},
  {"mode":"bare","input":"example.com:8443","error":"port"},
  {"mode":"bare","input":"[::1]","want":"::1"}
]
~~~

- [ ] **Step 2: Run red**

Run:

~~~bash
cd /home/mirivlad/git/verstak2/verstak-browser-extension
node scripts/test-hostname.js
cd /home/mirivlad/git/verstak2/verstak-desktop
GOCACHE=/tmp/verstak-go-cache go test ./internal/core/hostname -count=1
~~~

Expected: both fail because the normalizers do not exist.

- [ ] **Step 3: Implement both normalizers**

Use the browser URL parser plus ASCII IDNA conversion in JavaScript. Use
net/url, net/netip, and golang.org/x/net/idna.Lookup.ToASCII in Go. Store
ASCII A-labels, lowercase names, no ports or IPv6 brackets, and reject malformed
or over-limit values.

- [ ] **Step 4: Run green and commit**

Run:

~~~bash
cd /home/mirivlad/git/verstak2/verstak-browser-extension && npm test
cd /home/mirivlad/git/verstak2/verstak-desktop && GOCACHE=/tmp/verstak-go-cache go test ./internal/core/hostname -count=1
cmp /home/mirivlad/git/verstak2/verstak-sdk/schemas/hostname-normalization-v1.json /home/mirivlad/git/verstak2/verstak-browser-extension/shared/hostname-normalization-v1.json
cmp /home/mirivlad/git/verstak2/verstak-sdk/schemas/hostname-normalization-v1.json /home/mirivlad/git/verstak2/verstak-desktop/internal/core/hostname/testdata/hostname-normalization-v1.json
git -C /home/mirivlad/git/verstak2/verstak-sdk add schemas/hostname-normalization-v1.json
git -C /home/mirivlad/git/verstak2/verstak-sdk commit -m "feat: define hostname normalization vectors"
git -C /home/mirivlad/git/verstak2/verstak-browser-extension add shared/hostname.js shared/hostname-normalization-v1.json scripts/test-hostname.js
git -C /home/mirivlad/git/verstak2/verstak-browser-extension commit -m "feat: normalize activity hostnames"
git -C /home/mirivlad/git/verstak2/verstak-desktop add internal/core/hostname
git -C /home/mirivlad/git/verstak2/verstak-desktop commit -m "feat: normalize browser hostnames"
~~~

Expected: every copied corpus passes in both implementations.

### Task 2: Add a separate authenticated Desktop activity receiver

**Files:**
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/browserreceiver/receiver.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/core/browserreceiver/receiver_test.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/api/app.go
- Modify: /home/mirivlad/git/verstak2/verstak-desktop/internal/api/app_test.go

**Interfaces:**
- Accepts POST /activities with BrowserDomainActivity.
- Emits browser.activity.domain with normalized hostname, duration, ID, and optional workspaceId.
- Returns status accepted and activityId for first delivery and duplicate delivery.

- [ ] **Step 1: Write failing handler tests**

Create a valid immutable request and then retry the same ID:

~~~go
payload := "{\"schemaVersion\":1,\"activityId\":\"a-1\",\"hostname\":\"пример.рф\",\"durationSeconds\":300,\"startedAt\":\"2026-07-12T10:00:00Z\",\"endedAt\":\"2026-07-12T10:05:00Z\"}"
req := httptest.NewRequest(http.MethodPost, "/activities", strings.NewReader(payload))
req.Header.Set("X-Verstak-Receiver-Token", "pair-token")
~~~

Assert invalid tokens, URL-like hostnames, zero or oversize duration, and a
duplicate ID do not publish a second event.

- [ ] **Step 2: Run red**

Run:

~~~bash
cd /home/mirivlad/git/verstak2/verstak-desktop
GOCACHE=/tmp/verstak-go-cache go test ./internal/core/browserreceiver -run Activity -count=1
~~~

Expected: FAIL because /activities is not routed.

- [ ] **Step 3: Implement the bounded idempotent route**

Add BrowserDomainActivity, a 30-day bounded receiver ID cache, and
handleActivity which invokes hostname.NormalizeV1. Do not reuse capture types
or persistence. In App, resolve an active exact hostname binding to workspaceId
and a path cache before Activity receives the event.

- [ ] **Step 4: Run green and commit**

Run:

~~~bash
GOCACHE=/tmp/verstak-go-cache go test ./internal/core/browserreceiver ./internal/api -count=1
git add internal/core/browserreceiver/receiver.go internal/core/browserreceiver/receiver_test.go internal/api/app.go internal/api/app_test.go
git commit -m "feat: receive browser domain activity"
~~~

Expected: authentication, normalization, idempotency, and binding tests pass.

### Task 3: Build the opt-in extension tracker and immutable delivery queue

**Files:**
- Create: /home/mirivlad/git/verstak2/verstak-browser-extension/shared/activity-tracker.js
- Create: /home/mirivlad/git/verstak2/verstak-browser-extension/scripts/test-activity-tracker.js
- Modify: /home/mirivlad/git/verstak2/verstak-browser-extension/shared/api.js
- Modify: /home/mirivlad/git/verstak2/verstak-browser-extension/shared/background.js
- Modify: /home/mirivlad/git/verstak2/verstak-browser-extension/shared/popup/popup.html
- Modify: /home/mirivlad/git/verstak2/verstak-browser-extension/shared/popup/popup.js
- Modify: /home/mirivlad/git/verstak2/verstak-browser-extension/shared/popup/popup.css
- Modify: /home/mirivlad/git/verstak2/verstak-browser-extension/shared/locales/en.json
- Modify: /home/mirivlad/git/verstak2/verstak-browser-extension/shared/locales/ru.json
- Modify: /home/mirivlad/git/verstak2/verstak-browser-extension/chromium/manifest.json
- Modify: /home/mirivlad/git/verstak2/verstak-browser-extension/firefox/manifest.json

**Interfaces:**
- Persists activeAccumulator, pendingBatches, and acknowledgedIds under verstak.activityTracker.
- Produces sendActivity(receiverUrl, token, immutablePayload).
- Settings include passiveActivityEnabled false and excludedDomains empty.

- [ ] **Step 1: Write failing state-machine tests**

Cover consent, active-tab-only timing, long-gap discard, and the A/B batch case:

~~~js
tracker.addElapsed('example.com', 600, start, end);
const batchA = tracker.freeze('example.com');
tracker.addElapsed('example.com', 300, laterStart, laterEnd);
assert.equal(tracker.pendingBatches[0].payload.durationSeconds, 600);
tracker.acknowledge(batchA.activityId);
assert.equal(tracker.activeAccumulator['example.com'].durationSeconds, 300);
~~~

- [ ] **Step 2: Run red**

Run:

~~~bash
cd /home/mirivlad/git/verstak2/verstak-browser-extension
node scripts/test-activity-tracker.js
~~~

Expected: FAIL because the state machine is absent.

- [ ] **Step 3: Implement tracker, disclosure, and listeners**

Implement the tracker as pure functions. In background.js, register
tabs.onActivated, tabs.onUpdated, windows.onFocusChanged, idle.onStateChanged,
and a five-minute alarm only while opted in. Set idle detection to 600 seconds.
On a gap over 600 seconds, clock rollback, lock, or browser startup, reset the
active checkpoint without adding time. Retry frozen batches oldest-first and
remove only matching IDs.

Show an unchecked Russian/English consent explanation in settings. Add windows,
alarms, and idle permissions to both manifests. Keep manual capture queue and
popup actions unchanged.

- [ ] **Step 4: Run green and commit**

Run:

~~~bash
npm test
node scripts/test-activity-tracker.js
git add shared chromium/manifest.json firefox/manifest.json scripts/test-activity-tracker.js
git commit -m "feat: add opt-in browser domain tracker"
~~~

Expected: tracker unit tests and existing extension tests pass.

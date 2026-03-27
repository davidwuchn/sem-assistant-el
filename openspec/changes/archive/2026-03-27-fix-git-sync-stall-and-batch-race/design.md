## Context

The daemon currently has two reliability gaps that interact with cron-driven, asynchronous execution:

1. Git sync can stall permanently after a failed push. The current flow in `sem-git-sync-org-roam` short-circuits on clean working tree (`git status --porcelain`) and does not account for a branch being ahead of remote. If a commit succeeds and push fails, later cycles skip forever even though unpushed commits remain.
2. Inbox processing batch state is global (`sem-core--batch-id`, `sem-core--pending-callbacks`, watchdog timer state) while async callbacks arrive later. Overlapping cron cycles can mutate shared counters and temp files across batches, causing wrong planning triggers and cross-batch writes.

This change must preserve daemon safety (no crash propagation), keep behavior deterministic under overlap, and improve sync convergence under transient network or remote failures.

## Goals / Non-Goals

**Goals:**
- Make git sync converge when local branch is ahead even with no uncommitted changes.
- Enforce pull-before-push and define explicit failure handling for pull/push conflict paths.
- Add scheduled pre-pull execution before inbox processing windows with idempotent behavior.
- Isolate async batch processing so stale callbacks, watchdogs, and temp writes cannot affect newer batches.
- Keep existing module boundaries (`sem-core`, `sem-router`, `sem-git-sync`) and daemon non-crashing guarantees.

**Non-Goals:**
- Changing LLM prompt semantics or planner policy logic.
- Modifying RSS, WebDAV, or unrelated background jobs.
- Reworking integration test harness behavior.
- Introducing distributed locks or external coordination services.

## Decisions

### 1) Git sync state model moves from "dirty tree only" to "sync-needed"

Decision:
- Introduce a helper that computes sync intent from two checks:
  - working tree dirty status (`git status --porcelain`)
  - ahead/behind relationship with upstream (`git rev-list --left-right --count @{u}...HEAD` or equivalent)
- Treat "ahead > 0" as sync-needed even when working tree is clean.

Rationale:
- Directly addresses the known stall mode after failed push.
- Keeps behavior explicit and testable by separating tree-dirty from branch-divergence logic.

Alternatives considered:
- **Keep current behavior + periodic forced push attempts:** rejected because it still depends on detecting local commits and can hide state intent.
- **Always run commit/push regardless of state:** rejected due to noisy failures and unnecessary churn.

### 2) Pull-before-push is mandatory, with explicit outcome classification

Decision:
- In `sem-git-sync-org-roam`, run `git pull --rebase origin <tracked-branch>` (or tracked upstream equivalent) before push.
- If pull fails (conflict/divergence/auth/network), log `FAIL` with classification and return nil; do not continue to push.
- If pull succeeds, push (`git push origin`) and classify push failures similarly.

Rationale:
- Makes remote reconciliation explicit and prevents pushing from stale base.
- Improves observability and avoids silent "SKIP" convergence in failure states.

Alternatives considered:
- **Pull after push failure only:** rejected because it delays conflict detection and creates less predictable state transitions.
- **Merge-based pull default:** rejected in favor of rebase for linear automated sync history and smaller merge-noise footprint.

### 3) Add cron-driven pre-pull phase with duplicate-safe behavior

Decision:
- Add a lightweight pre-pull entry point in `sem-git-sync` intended to run every 5 minutes.
- Pre-pull performs repo/upstream validation and pull-only reconciliation, then exits without commit/push side effects.
- The scheduler (init/cron wiring) runs pre-pull at least 10 minutes before inbox processing windows; repeated runs are safe and produce no duplicate writes when no remote changes exist.

Rationale:
- Reduces contention during inbox processing windows by front-loading remote reconciliation.
- Improves success probability for later commit+push path.

Alternatives considered:
- **Only keep pull-before-push in main sync:** partially solves correctness, but not window-readiness and latency under overlap.
- **Single daily pre-pull:** rejected because it does not satisfy near-window freshness requirement.

### 4) Batch identity becomes an immutable capability token across async paths

Decision:
- Capture `sem-core--batch-id` at dispatch time and pass it in every async callback context.
- Update barrier/watchdog APIs to be batch-aware (e.g., `sem-core--batch-barrier-check batch-id`, watchdog callback closes over owning batch-id).
- Ignore stale callbacks/events when incoming batch-id does not match current active batch.

Rationale:
- Eliminates cross-cycle mutation of shared counters and planning triggers.
- Gives deterministic ownership for callbacks arriving out of order.

Alternatives considered:
- **Global lock to prevent overlap:** rejected because overlap can still happen via delayed async callbacks and lock contention creates operational dead zones.
- **Reset global state opportunistically in callbacks:** rejected as brittle and race-prone.

### 5) Temp task batch files are owned and validated by batch-id

Decision:
- Continue per-batch file naming (`/tmp/data/tasks-tmp-{batch-id}.org`) but enforce write-time validation that callback batch-id matches target file batch-id.
- Stale callbacks skip write and only emit diagnostic logs; no fallback write to current batch.

Rationale:
- Prevents data contamination across batches.
- Aligns storage isolation with callback/barrier isolation.

Alternatives considered:
- **Single shared temp file with mutex:** rejected because it serializes unrelated batches and still allows stale logical ownership.

## Risks / Trade-offs

- [Pull-before-push may increase transient failure surface (network/auth)] → Mitigation: classify errors clearly, keep retry on later cron cycles, and avoid silent SKIP.
- [Rebase pull can require conflict resolution and fail automation] → Mitigation: treat as explicit FAIL, preserve repository state for operator intervention, never force-reset.
- [Additional pre-pull cadence adds command churn] → Mitigation: keep pre-pull idempotent and lightweight; no commit/push side effects.
- [Batch-id filtering may drop very late but valid-looking callbacks] → Mitigation: this is intentional safety; stale outputs are logged and ignored to preserve correctness.
- [API signature changes (batch-aware barrier/watchdog) touch multiple modules] → Mitigation: add focused tests for overlap/stale callback scenarios before rollout.

## Migration Plan

1. Implement git-sync helper refactor (sync-needed detection + classified pull/push paths) behind existing entry point semantics.
2. Add pre-pull function and wire cron schedule in init/deployment config so it runs every 5 minutes and before inbox windows.
3. Introduce batch-aware callback context and barrier/watchdog signatures in `sem-core` and `sem-router`.
4. Add or update ERT tests for:
   - ahead-but-clean repo sync behavior
   - pull-before-push failure classification
   - stale callback ignored behavior
   - watchdog firing only for owning batch
   - temp-file write isolation by batch-id
5. Deploy with logs monitored for `git-sync` and `core/router` batch lifecycle entries.

Rollback strategy:
- Revert the change commit(s) to restore previous sync/batch behavior.
- Keep generated temp files cleaned by existing stale-file cleanup logic.

## Open Questions

- Should pull strategy be configurable (`--rebase` vs `--ff-only`) via env var for operators with strict history policies?
- Should pre-pull skip execution when no upstream is configured, or attempt remote auto-detection and log FAIL?
- Do we want explicit metrics counters (beyond logs) for stale-callback drops to track overlap frequency over time?

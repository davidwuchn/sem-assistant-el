## Why

Git sync can enter a stuck state after a single push failure: a commit is created, push fails, later cycles see a clean working tree and skip forever while local commits remain unpushed.

Inbox processing has a critical cross-cycle race risk: asynchronous callbacks and barrier counters are global, so overlapping cron cycles can mix batch state, write into the wrong temp batch file, and trigger planning at the wrong time.

## What Changes

- Require git sync to detect and recover "ahead-of-remote" state even when the working tree is clean.
- Require a pull step before push, and add cron-driven pre-pull scheduling so pull occurs before inbox batch processing windows.
- Define conflict/error behavior for pre-pull and pull-before-push so failures are explicit and do not silently stall sync.
- Require strict batch scoping for async callbacks, barrier accounting, watchdog firing, and temp-file writes so one batch cannot mutate another batch.
- Define stale-callback handling rules so late callbacks from older batches are ignored safely.
- Out of scope: LLM prompt behavior, planner scheduling policy semantics, WebDAV behavior, RSS generation, and integration test workflow changes.

## Capabilities

### New Capabilities

- `git-sync-prepull-scheduling`: Introduce scheduled pre-pull execution before inbox processing windows; cadence must support "at least 10 minutes before" and may run every 5 minutes without creating duplicate side effects.
- `batch-scoped-callback-isolation`: Every async unit must carry immutable batch identity; callbacks, barrier decrements, timeout/watchdog events, and temp writes must be rejected when batch identity is stale or mismatched.

### Modified Capabilities

- `sem-git-sync-org-roam`: Sync must not rely only on dirty-tree detection; it must push pending local commits when ahead, must perform pull-before-push, and must classify pull/push failures without silently converging to permanent SKIP.
- `inbox-processing`: Batch lifecycle must be race-safe across overlapping cron cycles; planning trigger conditions must be evaluated only for the owning batch and never by stale callbacks.

## Impact

Prevents permanent git-sync stall, reduces data-loss risk from cross-batch races, and improves operational determinism under transient network failures and overlapping cron execution.

Adds stricter state-validation paths and additional cron activity for pre-pull checks; expected tradeoff is slightly higher operational churn for significantly higher reliability.

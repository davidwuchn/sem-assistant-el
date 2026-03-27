## 1. Git sync-needed detection and pull/push flow

- [x] 1.1 Add a git sync-state helper in `sem-git-sync.el` that evaluates dirty working tree and ahead/behind upstream state.
- [x] 1.2 Update `sem-git-sync-org-roam` to treat ahead-with-clean-tree as sync-needed instead of permanent skip.
- [x] 1.3 Implement mandatory pull-before-push sequencing for sync-needed runs and stop before push when pull fails.
- [x] 1.4 Add explicit pull/push failure classification (conflict/auth/network/other detectable cases) to sync logs.

## 2. Pre-pull scheduling and idempotent behavior

- [x] 2.1 Add a pre-pull entry point that performs repo/upstream validation and pull-only reconciliation with no commit/push side effects.
- [x] 2.2 Wire cron/init scheduling so pre-pull is eligible every 5 minutes and runs at least 10 minutes before inbox windows.
- [x] 2.3 Ensure pre-pull no-change runs are idempotent and do not create duplicate side effects.

## 3. Batch-scoped async callback isolation

- [x] 3.1 Capture batch-id at dispatch and pass it through async callback context for inbox processing.
- [x] 3.2 Make barrier and watchdog handlers batch-aware so only the owning batch can mutate pending state or trigger planning.
- [x] 3.3 Enforce batch-id validation for writes to `/tmp/data/tasks-tmp-{batch-id}.org` and drop stale callback writes.
- [x] 3.4 Ignore and log stale callback events so they cannot affect active batch counters or planner triggers.

## 4. Tests and verification

- [x] 4.1 Add/extend ERT tests for ahead-but-clean sync-needed behavior and mandatory pull-before-push execution order.
- [x] 4.2 Add/extend ERT tests for pull/push failure classification and continued sync-needed behavior after failed push.
- [x] 4.3 Add/extend ERT tests for stale callback rejection, watchdog ownership, and batch-isolated temp-file writes.
- [x] 4.4 Run `eask test ert app/elisp/tests/sem-test-runner.el` and fix regressions introduced by this change.

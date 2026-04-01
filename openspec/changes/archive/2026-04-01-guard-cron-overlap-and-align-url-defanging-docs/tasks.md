## 1. Build the cron overlap guard primitives

- [x] 1.1 Add per-job lockfile acquire/release helpers with holder metadata and atomic write/rename semantics
- [x] 1.2 Implement stale-lock evaluation with configurable TTL and fail-closed behavior when lock freshness is uncertain
- [x] 1.3 Add crash-recovery takeover flow that verifies holder liveness before reclaiming stale locks

## 2. Apply deterministic overlap policy at cron entry points

- [x] 2.1 Wire guarded cron-triggered job entry points to use guard keys scoped by logical job identity
- [x] 2.2 Add explicit per-job overlap policy configuration (default `skip`, opt-in `serialize` where required)
- [x] 2.3 Ensure lock lifecycle cleanup is protected with `unwind-protect` so locks release on success and errors

## 3. Make guard outcomes observable and diagnosable

- [x] 3.1 Emit structured guard decision logs for acquire, skip/defer, reclaim attempt, reclaim result, and release
- [x] 3.2 Include guard key, policy, lock age, and decision reason in log payloads for overlap and recovery paths

## 4. Align URL defanging contract across runtime and docs

- [x] 4.1 Update runtime call sites so task/RSS operator-facing outputs follow the documented defanged URL behavior
- [x] 4.2 Ensure url-capture output stays canonical (`http://`/`https://`) and does not run `sem-security-sanitize-urls`
- [x] 4.3 Update repository and module documentation to state one authoritative output-specific URL contract

## 5. Verify behavior with focused regression coverage

- [x] 5.1 Add or update ERT tests for same-key overlap suppression and different-key parallel execution behavior
- [x] 5.2 Add tests for stale-lock reclaim and uncertain-age fail-closed behavior with deterministic assertions
- [x] 5.3 Add tests for url-capture canonical URL output (`Source` line and `#+ROAM_REFS`) and no defanging in persisted artifacts
- [x] 5.4 Run `eask test ert app/elisp/tests/sem-test-runner.el` and fix regressions related to the new guard and URL-contract changes

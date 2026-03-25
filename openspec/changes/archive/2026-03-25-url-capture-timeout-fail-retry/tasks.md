## 1. Timeout orchestration in URL capture

- [x] 1.1 Add a single 5-minute wall-clock timeout constant and wrap `sem-url-capture-process` orchestration with that budget.
- [x] 1.2 Ensure timeout expiration returns `nil` from `sem-url-capture-process` and follows a dedicated timeout failure branch.
- [x] 1.3 Pass the shared timeout budget to lower-level operations where supported so orchestration and sub-steps stay aligned.

## 2. Failure classification and retry behavior

- [x] 2.1 Add timeout-specific `FAIL` logging in URL capture that is distinguishable from non-timeout failures.
- [x] 2.2 Update router/caller handling so URL-capture timeout outcomes remain retryable under existing retry bookkeeping.
- [x] 2.3 Verify timeout failures do not mark `:link:` headlines as processed in cursor state.

## 3. Test coverage for timeout guarantees

- [x] 3.1 Add/extend `sem-url-capture` ERT tests for timeout classification and `nil` return within the timeout path.
- [x] 3.2 Add/extend `sem-router`/core retry tests to confirm timeout outcomes are retried and not written to `.sem-cursor.el`.
- [x] 3.3 Add assertions that timeout logs use explicit timeout-specific `FAIL` messaging while non-timeout failures remain distinct.

## 4. Validation and regression safety

- [x] 4.1 Run `sh dev/elisplint.sh` on modified Elisp files to verify delimiter correctness.
- [x] 4.2 Run `eask test ert app/elisp/tests/sem-test-runner.el` and fix regressions outside timeout paths.

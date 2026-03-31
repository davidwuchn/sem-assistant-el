## 1. Core Purge and Logging Updates

- [x] 1.1 Add `sem-core--purge-cursor-to-active-hashes` using atomic temp-write and rename semantics.
- [x] 1.2 Add `sem-core--purge-retries` to reset `.sem-retries.el` to an empty alist via atomic write.
- [x] 1.3 Extend `sem-core-purge-inbox` to collect retained headline hashes and run cursor/retries purge only in the 4AM window.
- [x] 1.4 Ensure cursor/retries purge still runs when inbox file is missing, using an empty active-hash set.
- [x] 1.5 Wrap cursor purge and retries purge in isolated `condition-case` blocks so one failure does not block other purge steps.
- [x] 1.6 Update `sem-core-log` to append a single formatted line with `write-region` append mode after heading creation succeeds.

## 2. Router, Planner, and Dependency Cleanup

- [x] 2.1 Remove dead `sem-router--route-to-url-capture` and verify no callsites remain.
- [x] 2.2 Remove `error-count` state and update final router summary logging/message strings to `Processed=%d, Skipped=%d`.
- [x] 2.3 Remove `websocket` from `Eask` dependencies.
- [x] 2.4 Remove `websocket` from init package loading in `app/elisp/init.el`.
- [x] 2.5 Update `sem-planner--parse-timestamp` so missing end-time defaults to start + 30 minutes with same-day `23:59` clamp in both string and `consp` branches.
- [x] 2.6 Remove redundant `23:59` fallback defaulting in `sem-planner--timestamp-to-epoch-range` so parsed end values are used directly.

## 3. Test and Validation Updates

- [x] 3.1 Add/adjust `sem-core-test.el` coverage for cursor rebuild from retained headlines, removed hash dropping, retries reset, 4AM-only behavior, and purge-step failure isolation.
- [x] 3.2 Update `sem-core-test.el` assertions that depended on old log entry placement so append-only logging behavior is validated.
- [x] 3.3 Update `sem-router-test.el` to remove expectations around deleted URL wrapper and dropped `Errors` summary field.
- [x] 3.4 Update `sem-planner-test.el` for no-end-time overlap semantics, including non-overlap at distant same-day times and overlap within 30 minutes.
- [x] 3.5 Update `sem-init-test.el` to remove websocket load-failure mocking tied to removed dependency.
- [x] 3.6 Run targeted ERT suites for modified modules, then run the full suite with `eask test ert app/elisp/tests/sem-test-runner.el`.

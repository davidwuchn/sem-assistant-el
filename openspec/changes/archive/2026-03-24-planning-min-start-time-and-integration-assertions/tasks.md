## 1. Pass 2 lower-bound context and prompt updates

- [x] 1.1 Update Pass 2 planning context construction to compute `runtime_now` once and derive `runtime_min_start` as `runtime_now + 1 hour`.
- [x] 1.2 Update Pass 2 prompt/instruction content so non-exception scheduling MUST be strictly greater than `runtime_min_start`.
- [x] 1.3 Preserve the explicit fixed-schedule exception for `Process quarterly financial reports` so its provided timestamp is kept unchanged.

## 2. Integration assertion implementation

- [x] 2.1 Add scheduled-time lower-bound assertion logic in `dev/integration/run-integration-tests.sh` for all scheduled tasks except the fixed-schedule exception.
- [x] 2.2 Add exact-match assertion logic in `dev/integration/run-integration-tests.sh` that verifies `Process quarterly financial reports` matches the timestamp from `dev/integration/testing-resources/inbox-tasks.org`.
- [x] 2.3 Normalize runtime and scheduled datetimes to a single timezone authority before comparisons and fail with task/timestamp diagnostics on violations.
- [x] 2.4 Update assertion sequencing so the new scheduled-time check is included in the full assertion run without short-circuiting.

## 3. Assertion contract and spec synchronization

- [x] 3.1 Update hardcoded assertion arrays/constants in `dev/integration/run-integration-tests.sh` to reflect added lower-bound checks and fixed-schedule exception handling.
- [x] 3.2 Update `openspec/specs/assertions/spec.md` constants/requirements references so they match the implemented integration assertion behavior.
- [x] 3.3 Confirm delta specs under `openspec/changes/planning-min-start-time-and-integration-assertions/specs/` remain aligned with implemented strict `>` semantics and exception rules.

## 4. Regression safety and verification

- [x] 4.1 Add or update unit tests for planning context/prompt generation to ensure `runtime_now`, `runtime_min_start`, strict `>` semantics, and exception behavior are covered.
- [x] 4.2 Run `eask test ert app/elisp/tests/sem-test-runner.el` and fix regressions related to planning or assertion-facing changes.
- [x] 4.3 Run `sh dev/elisplint.sh app/elisp/*.el` on touched Elisp files and resolve delimiter/lint issues before completion.

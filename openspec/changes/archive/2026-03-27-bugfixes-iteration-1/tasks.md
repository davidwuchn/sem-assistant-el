## 1. Router Write Serialization and Parse Safety

- [x] 1.1 Route async `:task:` callback Pass 1 temp-file writes through `sem-router--with-tasks-write-lock` only.
- [x] 1.2 Preserve existing lock contention behavior (retry delay/count, DLQ/error logging, and lock release via `unwind-protect`).
- [x] 1.3 Fix `sem-router--parse-headlines` debug preview bounds to use numeric positions only (no marker values in numeric operators).
- [x] 1.4 Add or update ERT tests validating guarded async write path usage and non-fatal parse debug logging.

## 2. Messages Flush Hash Dedup

- [x] 2.1 Add in-memory last-flushed hash tracking for `sem-core--flush-messages-daily` and compute deterministic snapshot hashes per invocation.
- [x] 2.2 Skip append when current `*Messages*` hash matches the last successfully flushed hash.
- [x] 2.3 Update hash state only after successful append, leaving state unchanged on append failure.
- [x] 2.4 Ensure UTC date rollover keeps prior behavior while treating new-day snapshots independently for dedup.
- [x] 2.5 Add or update ERT coverage for first flush, unchanged-content skip, changed-content append, failure retry eligibility, and date rollover.

## 3. Git-Sync Command Execution Safety

- [x] 3.1 Refactor `sem-git-sync--run-command` to execute program + argv directly without shell-string command invocation.
- [x] 3.2 Update git-sync call sites to pass command program/args explicitly, including arguments containing spaces or metacharacters as literals.
- [x] 3.3 Preserve caller-visible result shape and success/failure semantics (exit status and diagnostic output behavior).
- [x] 3.4 Add or update ERT tests for argv execution and command result compatibility.

## 4. Validation and Regression Guardrails

- [x] 4.1 Run targeted ERT test files for `sem-router`, `sem-core`, and `sem-git-sync` with `sem-mock.el` loaded first.
- [x] 4.2 Run `eask test ert app/elisp/tests/sem-test-runner.el` to validate full-suite regression safety.
- [x] 4.3 Run `sh dev/elisplint.sh` for touched Elisp files and resolve unmatched delimiter issues.

## 1. Structured logging and errors.org TODO formatting

- [x] 1.1 Update `sem-core-log` to wrap body in `(cl-block sem-core-log ...)` and keep file I/O inside `condition-case`.
- [x] 1.2 Add stderr-visible fallback `(message "SEM-STDERR: ...")` when `/data/sem-log.org` write fails, ensuring fallback path never raises.
- [x] 1.3 Update `sem-core-log-error` to append `/data/errors.org` entries in required TODO + DEADLINE + PROPERTIES + Input/Raw LLM Output format.
- [x] 1.4 Ensure `sem-core-log-error` still records FAIL/DLQ status via `sem-core-log` while preserving daemon non-crash behavior.

## 2. Security enforcement in task router callback

- [x] 2.1 In `sem-router--route-to-task-llm` callback, run `sem-security-verify-tokens-present` on raw LLM output before restoration.
- [x] 2.2 Reject responses with non-empty `expanded` results: skip write to tasks output and log CRITICAL incident via `sem-core-log-error`.
- [x] 2.3 Mark the headline hash as processed on security rejection to prevent infinite retry loops on leaked content.
- [x] 2.4 Keep normal callback flow unchanged when expansion is not detected (including missing-token cases).

## 3. Collision-safe hash identity for inbox parsing and purge

- [x] 3.1 Update `sem-router--parse-headlines` hash formula to `(secure-hash 'sha256 (json-encode (vector title tags-str body)))` using space-joined tags.
- [x] 3.2 Update `sem-core-purge-inbox` hash computation to exactly match router formula and include body text as third JSON vector element.
- [x] 3.3 Confirm parser output still returns plist keys `:title`, `:tags`, `:body`, `:point`, and `:hash` with tags stripped of colons.
- [x] 3.4 Verify debug preview logging in parse path uses numeric positions only (no marker objects in numeric operators).

## 4. Tests and regression coverage

- [x] 4.1 Add/adjust ERT tests for `sem-core-log-error` to assert TODO headline, DEADLINE, CREATED property, Input section, and Raw LLM Output section formatting.
- [x] 4.2 Add/adjust ERT tests for `sem-core-log` unwritable file handling to assert SEM-STDERR fallback and no propagated errors.
- [x] 4.3 Add/adjust ERT tests for router security callback to assert expansion detection occurs before restoration and triggers rejection + processed marking.
- [x] 4.4 Add/adjust ERT tests for hash parity between parser and purge, including body inclusion and delimiter-collision resistance.

## 5. Validation and rollout checks

- [x] 5.1 Run targeted ERT files affected by `sem-core`, `sem-router`, and security changes with `sem-mock` loaded first.
- [x] 5.2 Run full test suite via `eask test ert app/elisp/tests/sem-test-runner.el` and fix regressions.
- [x] 5.3 Run `sh dev/elisplint.sh` on modified elisp files to verify delimiter/parenthesis correctness.
- [x] 5.4 Document expected one-time post-deploy inbox reprocessing behavior in change notes for operator awareness.

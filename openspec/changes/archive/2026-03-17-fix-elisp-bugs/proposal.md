## Why

The Elisp daemon has seven bugs that prevent correct operation:

1. `sem-router-process-inbox` (sem-router.el:344) uses `cl-return-from` without a wrapping `cl-block`. Every cron run on an empty inbox signals an error.
2. URL headlines are marked processed at sem-router.el:370 before the async LLM call completes. Any failure (trafilatura or LLM) silently drops the headline with no retry.
3. `sem-llm--handle-api-error`, `sem-llm--handle-malformed-output`, `sem-llm--handle-success` (sem-llm.el:47–116) are defined but never called by production code. The test suite tests these functions directly; production uses a different inline implementation in sem-router.el.
4. `sem-security-sanitize-urls` is called on org-roam node LLM output at sem-url-capture.el:352, defanging `#+ROAM_REFS:` to `hxxps://`. This breaks org-roam link resolution. URL defanging must never be applied to org-roam nodes.
5. `sem-git-sync--run-command` (sem-git-sync.el:31–39) discards `call-process-shell-command`'s return value. The function always returns exit code 0. All git failures are silently treated as successes.
6. `sem-core-purge-inbox` (sem-core.el:412) uses `(t ...)` as the `condition-case` error specifier, masking Emacs quit signals.
7. `sem-core--flush-messages` is defined twice: in init.el:161 (without `make-directory`) and in sem-core.el:168 (with `make-directory`). The init.el definition is the inferior duplicate.

## What Changes

- `sem-router.el`: wrap `sem-router-process-inbox` body in `(cl-block sem-router-process-inbox ...)`. Move `sem-router--mark-processed` out of the dispatch site and into the URL capture callback. On nil filepath, apply the same bounded-retry/DLQ logic already used for `@task` headlines: call `sem-core--increment-retry`; if count ≥ 3, call `sem-core--mark-dlq`; otherwise leave unprocessed for next cron cycle.
- `sem-llm.el`: delete `sem-llm--handle-api-error`, `sem-llm--handle-malformed-output`, `sem-llm--handle-success`.
- `sem-url-capture.el`: remove the `sem-security-sanitize-urls` call. org-roam nodes must contain real `https://` URLs.
- `sem-git-sync.el`: fix `sem-git-sync--run-command` to capture and return the actual exit code from `call-process-shell-command`.
- `sem-core.el`: change `(t ...)` to `(error ...)` in `sem-core-purge-inbox` condition-case handler.
- `init.el`: remove the duplicate `sem-core--flush-messages` definition (lines 161–169). `sem-init--install-messages-hook` remains unchanged; it references the symbol, which resolves to the canonical definition in `sem-core.el`.
- Tests: update `sem-retry-test.el` (and any other test file) to remove tests for the deleted dead handler functions. Add or update tests covering: (a) URL capture bounded retry via router callback, (b) correct exit-code detection in `sem-git-sync--run-command`, (c) absence of URL defanging in org-roam output. All new test files must be wired into `sem-test-runner.el`; all tests must pass via `emacs --batch --load app/elisp/tests/sem-test-runner.el` with exit code 0.

## Capabilities

### New Capabilities

- `url-capture-bounded-retry`: When `sem-url-capture-process` callback delivers `nil` filepath, the router increments `sem-core--retries-file` for that headline hash. After 3 cumulative failures (trafilatura OR LLM, counted together), the headline is moved to DLQ via `sem-core--mark-dlq` and marked processed. Before 3 failures, the headline is left unprocessed and retried on the next 30-min cron cycle. Constraint: the retry counter key is the headline content hash (same key format as `@task` retries). Constraint: DLQ escalation writes to `/data/errors.org` and logs to `sem-log.org` with status DLQ.

### Modified Capabilities

- `sem-router-process-inbox`: Body wrapped in `(cl-block sem-router-process-inbox ...)`. The `cl-return-from` at sem-router.el:345 becomes valid. Behavior on empty inbox is unchanged: return nil immediately. Constraint: `cl-block` wraps only the body of the `condition-case` try-form, not the error handler.
- `sem-router--route-url-dispatch`: `sem-router--mark-processed` is removed from the dispatch site (sem-router.el:370). It is called only inside the `sem-url-capture-process` callback, and only when `filepath` is non-nil (success) or when `sem-core--mark-dlq` is called (3rd failure). Constraint: the `processed-count` increment at sem-router.el:371 is also removed from the dispatch site; it moves into the callback success branch.
- `sem-git-sync--run-command`: Captures the integer return value of `call-process-shell-command` directly into `exit-code`. The `buffer-string` / `re-search-backward` exit-code detection is deleted entirely. The function returns `(exit-code . output-string)` as documented. Constraint: output string is still collected via `buffer-string` after the process exits.
- `sem-security-sanitize-urls` usage: Called only in `sem-rss.el` (morning digest output) and in `sem-router.el` task-writing path (`tasks.org` output). Never called in `sem-url-capture.el`. Constraint: the `sem-security-sanitize-urls` function itself in `sem-security.el` is not modified.
- `sem-core-purge-inbox` error handler: `(t ...)` changed to `(error ...)`. Behavior is identical for all `error`-class signals. Emacs `quit` signal (from C-g) now propagates normally instead of being swallowed.
- `sem-core--flush-messages` (canonical): the definition in `sem-core.el:168` is the sole definition. The inferior copy in `init.el:161–169` is deleted. `sem-init--install-messages-hook` (init.el:171) is not changed.
- `sem-llm.el` public surface: `sem-llm--handle-api-error`, `sem-llm--handle-malformed-output`, `sem-llm--handle-success` are deleted. `sem-llm-request` is unchanged. Constraint: tests in `sem-retry-test.el` that test these three functions directly must be removed or rewritten to test the router callback behavior instead.

## Impact

- `sem-router-process-inbox` cron runs no longer error on empty inbox.
- URL capture failures are now retried up to 3 times before DLQ escalation, matching `@task` behavior.
- org-roam nodes written by `sem-url-capture` contain valid `https://` URLs in `#+ROAM_REFS` and `[[link]]` entries.
- `sem-git-sync` correctly detects and reports git command failures; failed pushes are logged as FAIL in `sem-log.org` instead of silently succeeding.
- `sem-core-purge-inbox` no longer masks Emacs quit signals.
- `sem-llm.el` no longer exports three functions that are not used by production code.
- `init.el` no longer shadows the canonical `sem-core--flush-messages` with a definition that omits `make-directory`.
- Test suite must be updated: remove tests for deleted dead handler functions; add tests for the new URL-capture bounded retry path in the router callback and for `sem-git-sync--run-command` exit-code detection.
- All new and modified tests must be wired into `sem-test-runner.el`. The runner is the single entry point: `emacs --batch --load app/elisp/tests/sem-test-runner.el`. No test file is valid unless it is `(load ...)`-ed or `(require ...)`-ed from `sem-test-runner.el`.
- Zero regressions: after all changes, `emacs --batch --load app/elisp/tests/sem-test-runner.el` must exit 0 with all tests passing. No pre-existing passing test may be broken.
- No behavior changes to `sem-rss.el`, `sem-security.el`, `sem-core.el` (except the one-line condition-case fix), `sem-llm-request`, or any startup sequence logic.
- No infra changes (Docker, cron, WebDAV, SSH keys, env vars) are in scope for this change.

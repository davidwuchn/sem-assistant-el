## Why

Three bugs cause silent data loss and broken inbox lifecycle in the running daemon:

1. **Bug 1 (Purge hash mismatch):** `sem-core-purge-inbox` computes headline hashes differently from `sem-router--parse-headlines`. The purge never matches any stored hash, so `inbox-mobile.org` grows forever and processed items are never removed.
2. **Bug 2 (Security block misuse in router):** `sem-router--route-to-task-llm` destructures the `sem-security-sanitize-for-llm` cons cell incorrectly. `sanitized-body` is always `nil`; the task body is silently dropped and never sent to the LLM.
3. **Bug 3 (tasks.org write race):** Multiple async LLM callbacks for `@task` headlines can fire concurrently within one cron cycle and all call `write-region` on `tasks.org` simultaneously, corrupting the file.

## What Changes

- `sem-core.el` — purge hash computation aligned to router's format (authoritative source: router)
- `sem-router.el` — security block destructuring corrected; mutex guard added for `tasks.org` writes
- `sem-core-test.el` — purge tests updated to use the corrected hash format
- `sem-router-test.el` — new tests for: correct security block round-trip, mutex contention behavior, and body-is-nil guard

## Capabilities

### New Capabilities

- `sem-router--tasks-write-lock`: A `defvar` boolean flag (default `nil`). Serializes concurrent writes to `tasks.org`. Any callback that finds the flag `t` re-schedules itself via `run-with-timer` (0.5 s delay, max 10 re-tries). After 10 failed re-tries the item is routed to the DLQ via `sem-core-log-error` and the lock is NOT held (lock is never held across retries — each attempt acquires and releases atomically using `unwind-protect`).

### Modified Capabilities

- `sem-core-purge-inbox`: Hash input changes from `(concat raw-line "|" colon-joined-tags)` to `(concat org-element-title "|" space-joined-tags "|" body)` — exactly matching `sem-router--parse-headlines`. No other behavior changes.
- `sem-router--route-to-task-llm`: Destructuring of `sem-security-sanitize-for-llm` return value corrected to `(car result)` / `(cdr result)`. When `sanitized-body` is the empty string after sanitization, the LLM call proceeds with an empty body (do NOT skip — empty body is valid for zero-body headlines). Security block restoration uses only the `cdr` (blocks alist), not the full cons cell.
- `sem-core-test.el` purge tests: All `secure-hash` literals updated to match the new format. No test logic changes beyond hash strings.
- `sem-router-test.el`: Three new ERT tests added (see Capabilities → New Capabilities for behavior specs of the lock). Existing tests must not be modified except where the hash format correction requires it.

## Impact

- All existing ERT tests must pass without modification (except hash literal strings in purge tests).
- Run: `emacs --batch --load app/elisp/tests/sem-test-runner.el`
- No changes to `sem-url-capture.el`, `sem-security.el`, `sem-llm.el`, `sem-rss.el`, or `sem-git-sync.el`.
- No changes to Docker, crontab, or data file formats.
- Out of scope: rate-limiting cron dispatch, message-flush race on log rotation, package lockfile hashes, Dockerfile.webdav cleanup.

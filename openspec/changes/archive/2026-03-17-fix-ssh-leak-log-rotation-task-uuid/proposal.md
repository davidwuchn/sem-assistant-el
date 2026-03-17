## Why

Three independent bugs degrade reliability and correctness of the SEM daemon:

1. `sem-git-sync--setup-ssh` spawns a new `ssh-agent` process on every git sync (every 6 h) without killing the previous one. Orphaned agent processes accumulate indefinitely until the container restarts.
2. `sem-core--flush-messages` appends the entire `*Messages*` buffer to a single `messages.log` on every `post-command-hook`. The buffer grows without bound (Emacs never truncates it automatically in daemon mode), making the file O(N²) over time and making log triage impossible.
3. `sem-router--route-to-task-llm` instructs the LLM to generate its own UUID for the `:ID:` field. LLMs produce non-unique, hallucinated, or malformatted UUIDs. The url-capture pipeline already solves this correctly by pre-generating the UUID in Emacs via `org-id-new` and injecting it into the prompt.

## What Changes

- `sem-git-sync`: `sem-git-sync--setup-ssh` is refactored to reuse an existing agent when a valid `SSH_AUTH_SOCK` socket file is already present. A new `sem-git-sync--teardown-ssh` function kills the agent after each sync. The agent lifecycle becomes: check-or-spawn → push → kill, all within a single `unwind-protect` in `sem-git-sync-org-roam`.
- `sem-core`: `sem-core--flush-messages` is replaced by `sem-core--flush-messages-daily`. The new function writes to `/var/log/sem/messages-YYYY-MM-DD.log`. On date rollover (new day detected), the `*Messages*` buffer is erased before writing, so old content does not bleed into the new day's file. The last-flush date is tracked in a module-level variable `sem-core--last-flush-date`.
- `sem-router`: `sem-router--route-to-task-llm` pre-generates the UUID via `(org-id-new)` before building the LLM prompt. The UUID is injected literally into the prompt template. The system prompt instructs the LLM to use the provided `:ID:` value verbatim. `sem-router--validate-task-response` is updated to accept the injected UUID as a required parameter and performs an exact-string-match check against the `:ID:` field in the LLM response. Mismatch → DLQ (same path as other malformed output).
- `tests`: New ERT tests cover all three bug fixes.

## Capabilities

### New Capabilities

- `ssh-agent-reuse`: Before spawning a new `ssh-agent`, check whether `SSH_AUTH_SOCK` env var is set AND the socket path exists on disk (`file-exists-p`). If both are true, skip `ssh-agent -s` and proceed directly to `ssh-add`. Only spawn a new agent if the check fails.
- `ssh-agent-teardown`: After `git push origin` completes (success or failure), unconditionally call `ssh-agent -k` using the `SSH_AGENT_PID` env var that was either pre-existing or freshly parsed. Implemented via `unwind-protect` in `sem-git-sync-org-roam` so teardown runs even if push raises a condition. If `SSH_AGENT_PID` is nil or agent was pre-existing (reused), do NOT kill it — only kill agents that were spawned in this sync cycle. A boolean `sem-git-sync--agent-spawned-this-cycle` (local variable, not persisted) tracks this.
- `daily-message-log`: `sem-core--flush-messages-daily` writes the `*Messages*` buffer to `/var/log/sem/messages-YYYY-MM-DD.log` where `YYYY-MM-DD` is today's date in container-local UTC time (consistent with existing `format-time-string` usage). The function is installed on `post-command-hook` in place of `sem-core--flush-messages`.
- `message-log-day-rollover`: The module-level variable `sem-core--last-flush-date` (string, `"YYYY-MM-DD"` format, initially `""`) stores the date of the last flush. On each invocation: if `today != sem-core--last-flush-date`, erase the `*Messages*` buffer (`erase-buffer` inside `with-current-buffer "*Messages*"`), then write to the new day's file, then update `sem-core--last-flush-date`. This guarantees the new day's file starts clean. The erase happens BEFORE writing so the write captures the first message of the new day.
- `task-uuid-injection`: `sem-router--route-to-task-llm` calls `(org-id-new)` to generate a UUID before constructing any prompt string. The UUID is bound to a `let`-scoped variable `injected-id`. The user-prompt template includes the literal string `:ID: <injected-id>` in the required output format block. The system-prompt includes the instruction: `"Use EXACTLY the :ID: value provided in the template below. Do not generate, modify, or substitute it."`. The `injected-id` is passed to the LLM callback via the context plist as `:injected-id`.
- `task-uuid-strict-validation`: `sem-router--validate-task-response` signature changes to `(response injected-id)`. The function extracts the `:ID:` value from the response using `re-search-forward "^:ID:[ \t]*\\([^[:space:]\n]+\\)"` and performs `(string= extracted-id injected-id)`. If the match fails or `:ID:` is absent, validation returns `nil` → response goes to DLQ. All callers of `sem-router--validate-task-response` must pass the injected UUID.

### Modified Capabilities

- `sem-git-sync--setup-ssh`: Returns `t` on success (agent reused or freshly spawned + key added). Returns `nil` on failure. Now also returns which path was taken via a new second return value (not used by callers — for testability only; use `cl-values` or simply document the boolean). **Constraint**: do NOT kill a pre-existing agent. Only kill agents spawned within the current sync cycle.
- `sem-core--flush-messages` → renamed to `sem-core--flush-messages-daily`: Old function removed. `init.el` already installs this via `sem-init--install-messages-hook`; the hook installation call must be updated to reference `sem-core--flush-messages-daily`. No other callers exist.
- `sem-router--validate-task-response`: Now takes `(response injected-id)`. Previously took `(response)` only. All internal call sites in `sem-router.el` updated. All test stubs updated.

## Test Requirements

- **All existing tests must continue to pass.** No existing test may be deleted or skipped. Tests whose function signatures change (e.g., `sem-router--validate-task-response`) must be updated to match the new signature — not removed.
- **All new tests must be registered in the test runner.** Every new `ert-deftest` must be added to `app/elisp/tests/sem-test-runner.el` via `(require ...)` of its test file before `ert-run-tests-batch-and-exit` is called. Tests not loaded by the runner are considered non-existent.
- **Single command must produce 100% pass.** The command `emacs --batch --load app/elisp/tests/sem-test-runner.el` must exit with code `0` and report zero failures and zero errors. This is the definition of done for the implementation phase.
- **No network, no filesystem side-effects in tests.** All new tests must use `sem-mock-*` infrastructure (or extend it) for external calls. Tests must not write to `/var/log/sem/` or `/data/` on the host; use `sem-mock-temp-file` / `make-temp-file` for any file I/O and clean up in `:teardown` or `unwind-protect`.
- **New test files:** `tests/sem-git-sync-test.el` and `tests/sem-core-test.el` already exist and must be extended in-place (not replaced). `tests/sem-router-test.el` already exists and must be extended in-place.

## Impact

- `sem-git-sync.el`: `sem-git-sync--setup-ssh`, `sem-git-sync-org-roam` modified. New internal variable `sem-git-sync--agent-spawned-this-cycle` (local to `sem-git-sync-org-roam`, not defvar).
- `sem-core.el`: `sem-core--flush-messages` removed. `sem-core--flush-messages-daily` added. `sem-core--last-flush-date` defvar added (initial value `""`).
- `init.el`: `sem-init--install-messages-hook` updated to reference `sem-core--flush-messages-daily`.
- `sem-router.el`: `sem-router--route-to-task-llm` modified (UUID injection). `sem-router--validate-task-response` signature changed.
- `tests/sem-git-sync-test.el`: New tests for agent reuse, teardown, and no-kill-on-reuse.
- `tests/sem-core-test.el`: New tests for daily log file naming, buffer erase on rollover, no-erase on same-day flush.
- `tests/sem-router-test.el`: Existing `sem-router--validate-task-response` tests updated for new signature. New tests: UUID mismatch → validation fails; UUID match → validation passes; injected UUID present in prompt string.
- No changes to: `sem-llm.el`, `sem-rss.el`, `sem-url-capture.el`, `sem-security.el`, `webdav-config.yml`, `docker-compose.yml`, `Dockerfile.emacs`, `crontab`.
- **Out of scope**: fixing straight.el lockfile placeholder SHAs; fixing org-roam DB rebuild on startup; fixing `*Messages*` buffer size in general (only the log write behavior changes); adding rate limiting for LLM requests; changing the git commit message format; changing the cron schedule.

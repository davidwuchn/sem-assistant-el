## Context

The Elisp daemon has accumulated seven bugs across multiple modules that prevent correct operation. These range from control flow errors (`cl-return-from` without `cl-block`) to silent failures (discarded exit codes, premature processing markers) to dead code (unused handler functions). The bugs affect cron job stability, URL capture reliability, git sync accuracy, and org-roam data integrity.

Current state:
- `sem-router-process-inbox` signals an error on every empty inbox run due to invalid `cl-return-from` usage
- URL capture failures are silently dropped with no retry mechanism
- Three handler functions in `sem-llm.el` are tested but never called by production code
- org-roam nodes have defanged URLs (`hxxps://`) due to incorrect sanitization
- Git sync always reports success regardless of actual command exit codes
- `sem-core-purge-inbox` masks Emacs quit signals
- Duplicate function definition shadows the canonical implementation

## Goals / Non-Goals

**Goals:**
- Fix all seven identified bugs with minimal, surgical changes
- Implement bounded retry (3 attempts) for URL capture failures, matching existing `@task` retry behavior
- Ensure all git commands report actual exit codes
- Preserve org-roam URL integrity by removing incorrect sanitization
- Clean up dead code and duplicate definitions
- Update test suite to cover new retry logic and exit code detection
- Achieve zero test regressions

**Non-Goals:**
- No changes to `sem-rss.el`, `sem-security.el` function definitions, `sem-llm-request`, or startup sequence
- No infrastructure changes (Docker, cron, WebDAV, SSH, env vars)
- No new features beyond the bounded retry mechanism
- No refactoring for refactoring's sake

## Decisions

### Decision 1: Wrap `sem-router-process-inbox` in `cl-block`
**Rationale:** The cleanest fix for the `cl-return-from` error. Wrapping only the try-form body (not the error handler) maintains existing error handling behavior while making the block exit valid.

**Alternative considered:** Replace `cl-return-from` with a flag variable and conditional checks. Rejected as it would require more invasive changes throughout the function.

### Decision 2: Move processing markers into the URL capture callback
**Rationale:** The callback (`sem-url-capture-process`) already receives the success/failure result via its `filepath` parameter. Moving `sem-router--mark-processed` and `processed-count` increment into the callback ensures processing state only advances on completed (success or DLQ) outcomes, not on dispatch.

**Alternative considered:** Add a promise/future mechanism for async tracking. Rejected as overkill; the existing callback pattern is sufficient.

### Decision 3: Reuse existing `@task` retry infrastructure for URL capture
**Rationale:** The `sem-core--increment-retry` and `sem-core--mark-dlq` functions already implement bounded retry with DLQ escalation. Using the same key format (headline content hash) and retry file ensures consistency.

**Alternative considered:** Create separate retry tracking for URLs. Rejected as it would duplicate logic and risk inconsistent behavior.

### Decision 4: Delete dead handler functions rather than wiring them up
**Rationale:** `sem-llm--handle-api-error`, `sem-llm--handle-malformed-output`, and `sem-llm--handle-success` have been unused since the router callback pattern was adopted. Deleting them reduces maintenance burden. The router callback already handles these cases inline.

**Alternative considered:** Refactor router to use these functions. Rejected as unnecessary churn; the inline implementation is working correctly.

### Decision 5: Remove `sem-security-sanitize-urls` call from `sem-url-capture.el` only
**Rationale:** The function is still needed for RSS digest output (`sem-rss.el`) and task writing (`sem-router.el`). Removing only the call site in `sem-url-capture.el` fixes the org-roam issue while preserving security for other outputs.

**Alternative considered:** Modify `sem-security-sanitize-urls` to detect org-roam context. Rejected as more complex and riskier than removing the incorrect call.

### Decision 6: Direct return value capture in `sem-git-sync--run-command`
**Rationale:** `call-process-shell-command` returns the exit code directly. Capturing this into a variable and returning it as the car of the result cons cell fixes the bug with minimal change.

**Alternative considered:** Keep the `buffer-string` / `re-search-forward` exit code detection. Rejected as it was never working correctly and is unnecessary complexity.

### Decision 7: Change `(t ...)` to `(error ...)` in condition-case
**Rationale:** `(error ...)` catches only error-class signals, allowing `quit` (C-g) to propagate. This is the standard Emacs pattern for non-masked error handling.

**Alternative considered:** Remove the condition-case entirely. Rejected as we still want to handle actual errors gracefully.

### Decision 8: Remove duplicate from `init.el`, keep canonical in `sem-core.el`
**Rationale:** The `sem-core.el` version includes `make-directory` which ensures the messages directory exists. The `init.el` version lacks this and shadows the canonical definition.

**Alternative considered:** Merge the definitions. Rejected as the `sem-core.el` version is strictly better.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Moving processing markers to callback may affect `processed-count` timing | Verify callback runs synchronously in the async handler; count increment happens before callback returns |
| Retry counter shared with `@task` may have key collision | Use headline content hash which is deterministic and unique per headline content |
| Deleting dead functions may break external scripts | Search codebase confirms no references outside test files; tests updated |
| Removing URL sanitization from capture may expose security risk | URLs in org-roam are user-facing links, not executed code; RSS and task outputs still sanitized |
| Git exit code change may reveal previously hidden failures | This is the intended behavior; monitoring will show actual git status |

## Migration Plan

No runtime migration needed. Changes are deployed via standard git pull + Emacs restart.

Rollback: Revert the commit and restart Emacs. All changes are backward-compatible except the git exit code fix, which only affects logging accuracy (a good thing).

## Open Questions

None. All technical decisions are resolved.

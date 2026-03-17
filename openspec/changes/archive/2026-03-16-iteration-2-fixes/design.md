## Context

This change addresses five critical defects in the Emacs-based assistant system that prevent it from functioning as documented in the README:

1. **Parse crash**: `sem-router--parse-headlines` uses `cl-return-from` without a `cl-block`, causing crashes every 30-minute cron run
2. **Task inbox silent discard**: `@task` headlines are marked processed without LLM processing
3. **Security functions unused**: `sem-security-sanitize-for-llm` and `sem-security-sanitize-urls` are implemented but never called
4. **Purge data loss**: `sem-core-purge-inbox` discards body content of unprocessed headlines at 4AM
5. **Bypassed retry policy**: `sem-rss--generate-file` calls `gptel-request` directly, bypassing the retry/DLQ policy

**Current state**: The system has modular Elisp files (`sem-router.el`, `sem-core.el`, `sem-url-capture.el`, `sem-rss.el`) with existing security utilities and LLM request handling infrastructure that are not being utilized.

**Constraints**:
- Changes must be limited to fixing the specific defects identified
- The retry/DLQ policy via `sem-llm-request` must be consistently applied
- Task tags must come from the allowed list defined in `sem-router-task-tags`
- Backward compatibility with existing org file formats must be maintained

## Goals / Non-Goals

**Goals:**
- Eliminate the parse crash by adding proper `cl-block` wrapper
- Implement full LLM pipeline for `@task` headlines with auto-tagging and validation
- Wire security masking into the URL capture pipeline
- Fix purge to preserve full headline subtrees for unprocessed items
- Route RSS digest generation through the standard retry/DLQ policy
- Add comprehensive tests for all fixes

**Non-Goals:**
- No refactoring of unrelated code paths
- No changes to the org file format or data structures
- No modifications to `sem-security-restore-from-llm` usage (explicitly not called in url-capture)
- No changes to the cron scheduling or deployment infrastructure

## Decisions

### 1. Minimal `cl-block` wrapper for parse fix
**Decision**: Wrap `sem-router--parse-headlines` body with `(cl-block sem-router--parse-headlines ...)` without changing any internal logic.

**Rationale**: The proposal explicitly constrains this fix to adding only the `cl-block` wrapper. This eliminates the crash while maintaining existing behavior.

**Alternatives considered**:
- Refactor to use `return` instead of `cl-return-from`: Would require touching more code, increasing risk
- Restructure the entire function: Unnecessary scope creep for a bug fix

### 2. Task LLM pipeline with tag validation at Elisp layer
**Decision**: Send `@task` headlines to LLM, expect valid org TODO entry with `:FILETAGS:`, validate the tag against `sem-router-task-tags`, and substitute `:routine:` if absent or invalid.

**Rationale**: The LLM may return invalid tags; validating at the Elisp layer ensures data integrity before writing to `tasks.org`. Defaulting to `:routine:` provides a safe fallback.

**Alternatives considered**:
- Reject invalid tags and retry: Would cause unnecessary API calls and potential infinite loops
- Allow any tag: Violates the constraint that tags must come from the predefined list

### 3. Security masking before LLM, URL defanging after LLM
**Decision**: Call `sem-security-sanitize-for-llm` on input text before `sem-llm-request`; call `sem-security-sanitize-urls` on raw LLM response before validation/save.

**Rationale**: Input sanitization protects sensitive data from being sent to the LLM. Output URL defanging ensures captured URLs are safe before file write. Not calling `sem-security-restore-from-llm` is intentional since LLM output is a new document, not a transformation.

**Alternatives considered**:
- Restore blocks after LLM: Would defeat the purpose since LLM generates new content
- Sanitize only on output: Would expose sensitive data in LLM requests

### 4. Region-based subtree copy for purge
**Decision**: Use region-based or org-element-based copy to preserve full headline subtrees (title + all body lines until next top-level headline or EOF).

**Rationale**: String-based title-only write causes silent data loss. Region/org-element approaches ensure complete subtree preservation while maintaining atomic rename behavior.

**Alternatives considered**:
- Continue with title-only write: Unacceptable data loss
- Full file rewrite with filtering: More complex, higher risk of bugs

### 5. Route RSS through `sem-llm-request` with `nil` hash
**Decision**: Replace direct `gptel-request` call with `sem-llm-request`, passing `nil` as the hash argument.

**Rationale**: RSS digest has no per-entry cursor deduplication, so `nil` hash is appropriate. `sem-llm-request` must handle `nil` hash gracefully (e.g., `sem-core--mark-processed nil` must be a no-op).

**Alternatives considered**:
- Generate a synthetic hash: Unnecessary complexity for a daily digest
- Keep direct `gptel-request` call: Would bypass retry/DLQ policy

## Risks / Trade-offs

**[Risk] LLM returns malformed output for tasks** → Mitigation: Malformed output goes to `errors.org` and hash is marked as processed (no infinite retry). This is acceptable data loss for invalid responses.

**[Risk] API errors cause retry storms** → Mitigation: API errors leave hash unrecorded, retry happens next cron run (30 minutes later). Rate limiting is inherent in the cron schedule.

**[Risk] Tag validation rejects valid but unexpected tags** → Mitigation: The allowed tag list is a `defconst` requiring code change to modify. This is intentional—changing tags requires rebuild.

**[Risk] Region-based copy may include unintended content** → Mitigation: Test with headlines containing various body structures to ensure correct boundary detection.

**[Risk] `nil` hash handling in `sem-llm-request` may crash** → Mitigation: Add explicit nil checks in `sem-core--mark-processed` and related functions.

**[Trade-off] Silent data loss for malformed LLM output** → Acceptable because infinite retries would be worse; errors are logged for manual review.

**[Trade-off] No restore-from-llm in url-capture** → Intentional design: LLM output is new content, not transformed input, so block restoration doesn't apply.

## Migration Plan

**Deployment steps:**
1. Apply code changes to Elisp files
2. Run new tests to verify fixes
3. Rebuild Docker container (required for `defconst` tag changes)
4. Deploy updated container
5. Monitor next cron run for parse crash elimination
6. Monitor `errors.org` for any malformed LLM outputs

**Rollback strategy:**
- Revert to previous Docker image version
- No data migration required (org file formats unchanged)
- Inbox headlines will re-process on next run if needed

## Open Questions (Resolved)

1. Should the default tag for tasks be `:routine:` or should invalid-tag tasks go directly to `errors.org`? :routine: is default
2. Is 30-minute retry interval appropriate for API errors, or should exponential backoff be considered? keep 30 minutes for now
3. Should there be a maximum retry count before giving up on a headline? 3 at most

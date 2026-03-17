## Context

Two critical bugs exist in the sem-assistant-el codebase:

1. **Sensitive Content Loss in URL Capture**: The `sem-url-capture-process` function correctly strips sensitive content blocks before sending to the LLM (via `sem-security-strip-for-llm`), storing them in a `security-blocks` alist within the context plist. However, after receiving the LLM response, the sensitive blocks are never restored. The `sem-security-restore-from-llm` function exists but is never called in the pipeline, causing any content wrapped in `#+begin_sensitive...#+end_sensitive` blocks to be permanently lost from the saved org-roam node.

2. **GitHub Sync Module Never Loaded**: The `sem-git-sync` module exists and provides `sem-git-sync-org-roam`, but `sem-init--load-modules` in `init.el` never calls `(require 'sem-git-sync)`. This causes every cron-triggered sync attempt to fail with `void-function` error. The feature has been completely non-functional.

## Goals / Non-Goals

**Goals:**
- Restore sensitive content blocks into the LLM response before saving to org-roam nodes
- Ensure `sem-git-sync` module is properly loaded during initialization
- Update the security-masking spec to reflect the correct behavior
- Add comprehensive ERT tests for both fixes

**Non-Goals:**
- No changes to `sem-security.el` core functions (strip/restore logic is correct)
- No changes to `sem-git-sync.el` implementation (just loading)
- No changes to the cron schedule or sync logic
- No refactoring of unrelated code

## Decisions

### Decision 1: Restore Call Placement in LLM Callback
**Choice**: Call `sem-security-restore-from-llm` immediately after the `response` nil-check and before `sem-url-capture--validate-and-save`.

**Rationale**: 
- The restore must happen on the raw LLM response string before any validation/saving
- Keeping it close to where `response` is first used minimizes risk of intermediate processing
- This follows the natural data flow: receive response → restore tokens → validate → save

**Alternative considered**: Restore inside `sem-url-capture--validate-and-save` - rejected because it would require passing `security-blocks` deeper into the call stack, increasing coupling.

### Decision 2: Load Order for sem-git-sync
**Choice**: Load `sem-git-sync` after `sem-url-capture` and before `sem-router`.

**Rationale**:
- `sem-url-capture` is a core feature that should be loaded early
- `sem-router` may depend on sync capabilities being available
- This maintains the existing dependency chain without circular references

**Alternative considered**: Load at the very end - rejected because other modules might depend on sync functions being available.

### Decision 3: Test Strategy
**Choice**: Three separate ERT tests covering unit, integration, and module loading.

**Rationale**:
- Unit test for `sem-security-restore-from-llm` ensures the restore function works correctly
- Integration test for the full `sem-url-capture-process` callback path ensures the restore is called at the right place
- Module load test ensures the require statement is present and correct

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Restore call might fail if `security-blocks` is malformed | The restore function handles nil/empty blocks gracefully; tokens without matches are left as-is |
| Adding require statement could cause load errors if file missing | File exists in repo; require will fail fast during development if path issues exist |
| Tests might be brittle if internal function signatures change | Tests use public API where possible; integration test uses stubbing which is more resilient |
| Existing tests might break | All existing tests must pass; new tests are additive only |

## Migration Plan

No special migration needed - these are bug fixes that restore intended behavior:

1. Deploy code changes
2. New URL captures will automatically preserve sensitive blocks
3. Git sync cron job will start working on next 6-hour cycle
4. No rollback strategy needed (changes are purely additive/fixing broken functionality)

## Open Questions

None - the implementation approach is straightforward and well-defined.

## Context

The fix-test-failures change addresses 4 failing ERT tests (out of 45 total) caused by three distinct root causes:

1. **sem-core-log bug**: Uses `cl-return-from` without a `cl-block`, causing the macro to emit a `throw` with no matching `catch`. The `condition-case` handler silently swallows the error.

2. **sem-url-capture-process bypass**: Calls `gptel-request` directly instead of through `sem-llm-request`, skipping hash tracking and DLQ logging.

3. **trafilatura mock issue**: Uses `:filter-args` advice which cannot return values, causing mocks to never intercept properly.

**Constraints:**
- Production code has zero behavior change for `sem-core-log` since the buggy branch was never reached at runtime
- Function signatures must remain unchanged (e.g., `sem-url-capture--validate-and-save`)
- Mocks must only intercept trafilatura calls, passing through all other `call-process` calls

**Stakeholders:** Test suite maintainers, developers relying on test feedback

## Goals / Non-Goals

**Goals:**
- Fix all 4 failing tests to restore 100% test pass rate
- Ensure `sem-core-log` uses proper `cl-block` for `cl-return-from`
- Route `sem-url-capture-process` LLM calls through `sem-llm-request` for proper tracking
- Fix trafilatura mocks to use `:override` advice that can return values
- Add new tests for the url-capture process happy path and DLQ path

**Non-Goals:**
- Fixing `sem-router--route-to-task-llm` stub
- Fixing `sem-core--flush-messages` redefinition in `init.el`
- arXiv digest functionality
- Docker/cron configuration changes
- Any production behavior changes beyond what's needed to fix tests

## Decisions

### Decision 1: Use `cl-block` wrapper for `sem-core-log`

**Choice:** Wrap the entire body of `sem-core-log` in `(cl-block sem-core-log ...)`

**Rationale:** `cl-return-from` requires a matching `cl-block` to work correctly. Without it, the macro emits a `throw` statement that has no matching `catch`, leading to the error being swallowed by the `condition-case` handler.

**Alternatives considered:**
- Replace `cl-return-from` with `cl-return` - Less explicit, harder to understand which block is being returned from
- Rewrite the function to avoid early returns - Would change the logic structure unnecessarily

### Decision 2: Replace direct `gptel-request` with `sem-llm-request`

**Choice:** Modify `sem-url-capture-process` to call `sem-llm-request` instead of `gptel-request` directly, passing `sem-url-capture--validate-and-save` as the success callback via the context plist.

**Rationale:** `sem-llm-request` provides hash tracking and DLQ logging that are essential for the system's correctness. Using it ensures consistent behavior across all LLM calls.

**Alternatives considered:**
- Add hash tracking manually to the direct call - Would duplicate logic already in `sem-llm-request`
- Create a new wrapper function - Unnecessary indirection when `sem-llm-request` already exists

### Decision 3: Change mock advice from `:filter-args` to `:override`

**Choice:** Replace `:filter-args` advice with `:override` advice on `call-process` for both `sem-mock-trafilatura-success` and `sem-mock-trafilatura-failure`.

**Rationale:** `:filter-args` advisors must return a (possibly modified) argument list and cannot return arbitrary values. The `:override` advice can return any value, allowing proper mock behavior.

**Alternatives considered:**
- Use a different mocking framework - Would add dependencies and learning curve
- Keep `:filter-args` and work around the limitation - Not possible; the advisor fundamentally cannot return values

### Decision 4: Guard mocks with string comparison

**Choice:** The `:override` advice must check `(string= (car args) "trafilatura")` before intercepting, passing through all other calls via `apply #'call-process--original args`.

**Rationale:** Prevents the mock from interfering with other `call-process` calls in the system, ensuring test isolation.

## Risks / Trade-offs

**[Risk]** The `cl-block` change to `sem-core-log` could theoretically affect error handling behavior if the function is called in unexpected contexts.

→ **Mitigation:** The production code path never triggers the `cl-return-from` branch (only happens on writable `/data/` filesystem). Test coverage will validate the fix.

**[Risk]** Changing from `gptel-request` to `sem-llm-request` could introduce subtle differences in callback behavior or error handling.

→ **Mitigation:** The function signature of `sem-url-capture--validate-and-save` remains unchanged. New tests will cover both happy path and DLQ path.

**[Risk]** The `:override` advice on `call-process` could have performance implications if the string check is expensive.

→ **Mitigation:** `string=` is a fast operation. The check only happens during tests, not production.

**[Trade-off]** Keeping the `(t nil)` error handler in `sem-core-log` maintains backward compatibility but continues to silently swallow errors.

→ **Mitigation:** Out of scope for this change; could be addressed in future logging improvements.

## Open Questions

None - the implementation approach is well-defined by the proposal.

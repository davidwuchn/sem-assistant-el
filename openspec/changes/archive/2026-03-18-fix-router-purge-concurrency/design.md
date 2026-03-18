## Context

This change addresses three critical bugs in the sem-assistant-el daemon that cause silent data loss and broken inbox lifecycle:

1. **Hash computation mismatch**: The purge function uses a different hash format than the router, causing inbox items to never be removed
2. **Security block destructuring**: The router incorrectly destructures the security sanitizer's return value, dropping task bodies
3. **Concurrent write race**: Multiple async LLM callbacks can corrupt `tasks.org` through simultaneous writes

The codebase is Emacs Lisp with ERT tests. The affected modules are `sem-core.el` (purge functionality) and `sem-router.el` (routing and LLM integration).

## Goals / Non-Goals

**Goals:**
- Align purge hash computation with router's format to ensure proper inbox cleanup
- Fix security block destructuring to preserve task bodies through sanitization
- Prevent concurrent writes to `tasks.org` via a mutex/lock mechanism
- Maintain all existing test coverage with updated hash literals
- Add new tests for security block round-trip, mutex contention, and nil body guards

**Non-Goals:**
- Changes to other modules (`sem-url-capture.el`, `sem-security.el`, `sem-llm.el`, etc.)
- Infrastructure changes (Docker, crontab)
- Data file format changes
- Rate-limiting cron dispatch
- Message-flush race on log rotation

## Decisions

### Decision 1: Router as Authoritative Hash Source
**Rationale**: The router's `sem-router--parse-headlines` is the entry point that creates the stored hashes. The purge function must match this format exactly. Changing the router would require updating all stored hashes in the database, which is riskier.

**Chosen approach**: Modify `sem-core-purge-inbox` to use the same hash format as `sem-router--parse-headlines`.

**Alternative considered**: Updating the router's hash format and migrating existing data — rejected due to migration complexity and risk.

### Decision 2: Boolean Flag for Mutex (vs Emacs Mutex Primitive)
**Rationale**: Emacs Lisp has `mutex-lock` in `thread-lib`, but the async callbacks are likely using `run-with-timer` and timers, not true threads. A simple boolean flag with atomic check-and-set is sufficient and more portable.

**Chosen approach**: Use a `defvar` boolean flag `sem-router--tasks-write-lock` with atomic acquire/release via `unwind-protect`.

**Alternative considered**: Using `make-mutex` from `thread-lib` — rejected because timers don't use threads, and the mutex would add unnecessary complexity.

### Decision 3: Retry with Exponential Backoff (vs Queue)
**Rationale**: A queue would require persistent state and more complex queue management. For this use case, simple retries with a fixed delay are sufficient.

**Chosen approach**: Retry with 0.5s fixed delay, max 10 retries, then route to DLQ.

**Alternative considered**: In-memory queue with retry scheduling — rejected as over-engineered for the expected contention frequency.

### Decision 4: Empty String is Valid Body (vs Skip)
**Rationale**: Headlines can legitimately have no body. Skipping them would lose valid tasks.

**Chosen approach**: When `sanitized-body` is empty string, proceed with LLM call using empty body.

**Alternative considered**: Skip headlines with empty body — rejected as it would cause data loss for zero-body headlines.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Hash change causes existing inbox items to not match | This is intentional — old items will be purged on next cycle; new items will use correct format |
| Lock flag could be left in locked state on error | Use `unwind-protect` to ensure flag is always cleared |
| Retry exhaustion drops items to DLQ | DLQ logging ensures visibility; manual reprocessing possible |
| Empty body causes LLM errors | LLM should handle empty input gracefully; this is existing behavior for truly empty headlines |
| Test hash literals need updating | Documented in proposal; tests will fail until updated |

## Migration Plan

1. **Deploy**: Update `sem-core.el` and `sem-router.el`
2. **Verify**: Run `emacs --batch --load app/elisp/tests/sem-test-runner.el`
3. **Monitor**: Check DLQ logs for items that exhausted retries
4. **Rollback**: Revert to previous git commit; no data migration needed

## Open Questions

None — all technical decisions resolved.

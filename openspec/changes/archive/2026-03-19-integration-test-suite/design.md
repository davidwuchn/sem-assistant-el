## Context

The SEM Assistant Elisp daemon processes inbox notes and RSS feeds via LLM (OpenRouter/gptel). The current test coverage consists only of unit tests that mock all external calls. There is no automated way to verify that a real inbox headline flows through the full pipeline:

1. WebDAV upload → 
2. Emacs LLM processing → 
3. tasks.org write → 
4. WebDAV retrieval

This gap makes regressions invisible until production breaks.

**Current State:**
- Unit tests exist in `app/elisp/tests/` using ERT framework
- All external dependencies (gptel, elfeed, org-roam) are mocked
- No end-to-end verification of the complete processing pipeline

**Constraints:**
- Must use `podman` and `podman-compose` exclusively (no Docker)
- Real LLM calls via OpenRouter cost money — suite is never run automatically
- Requires explicit operator invocation only
- Must clean up containers unconditionally (trap on EXIT)
- `OPENROUTER_KEY` env var must be set

**Stakeholders:**
- Human operator who runs the suite manually
- Developers who need confidence that changes don't break the full pipeline

## Goals / Non-Goals

**Goals:**
- Create a self-contained integration test suite under `dev/integration/`
- Verify the complete inbox processing pipeline end-to-end
- Collect artifacts (tasks.org, logs, container logs) for post-mortem analysis
- Provide clear pass/fail assertions with meaningful error messages
- Ensure complete cleanup regardless of test outcome

**Non-Goals:**
- URL capture testing (explicitly out of scope)
- Performance or load testing
- Continuous/automated execution (never runs in CI)
- Testing RSS feed processing
- Testing elfeed/org-roam integration

## Decisions

### 1. Podman over Docker

**Decision:** Use `podman` and `podman-compose` exclusively.

**Rationale:** The project uses Podman for local development. Using Docker would require the operator to have Docker installed separately, adding friction. The override compose file inherits from the main `docker-compose.yml`, so the same images and services are used.

**Alternatives Considered:**
- Docker: Rejected because the project already uses Podman; adding Docker support doubles maintenance burden.

### 2. Compose Override Pattern

**Decision:** Use a compose override file (`docker-compose.test.yml`) rather than a standalone compose file.

**Rationale:** The override pattern means the test compose file only specifies differences from production. This reduces drift and ensures test environment stays in sync with production configuration. Changes to the main `docker-compose.yml` (new environment variables, volume changes) automatically apply to tests without modifying the override.

**Alternatives Considered:**
- Standalone compose: Rejected — would require duplicating all service definitions, creating drift risk.

### 3. Timestamp-Based Run Directories

**Decision:** Create timestamped directories under `test-results/YYYY-MM-DD:HH:MM:SS-run/`.

**Rationale:** 
- Allows multiple runs without overwriting previous results
- Easy to identify which run corresponds to which artifacts
- Directory name is sortable and human-readable

**Alternatives Considered:**
- Sequential numbering (run-001/): Less intuitive for correlating with log timestamps
- Single results directory: Would overwrite previous runs, making post-mortem difficult

### 4. Poll-Based Async Handling

**Decision:** Poll for daemon readiness and task completion rather than using sleep timers.

**Rationale:**
- More robust — adapts to actual container startup time
- Faster failure detection than fixed sleep
- Maximum wait limits prevent infinite loops

**Alternatives Considered:**
- Fixed sleep: Could miss timing issues, wastes time on fast machines
- Webhook/callback: Too complex for this use case

### 5. Trap-Based Cleanup

**Decision:** Use `trap ... EXIT` as the first action after argument validation.

**Rationale:**
- Guarantees cleanup even on signal interrupt (SIGINT, SIGTERM)
- Prevents orphaned containers from previous failed runs
- Ensures `test-data/` and logs are available for debugging

**Alternatives Considered:**
- Manual cleanup: Error-prone, operator might forget
- Cleanup on next run: Previous run's data could interfere

### 6. Three-Headline Test Data

**Decision:** Use exactly 3 headlines in the test inbox: one `:routine:`, one `:work:`, one bare `@task`.

**Rationale:**
- Tests the three main tag normalization paths
- Minimal but sufficient to verify pipeline works
- More headlines would increase LLM cost without proportional coverage gain

**Alternatives Considered:**
- Single headline: Doesn't test tag routing
- Many headlines: Higher cost, diminishing returns

### 7. Org Validity Check via Emacs Batch

**Decision:** Use `org-element-parse-buffer` in batch mode to validate output.

**Rationale:**
- Uses Emacs's own parser — authoritative validation
- Catches structural issues that grep might miss
- Reuses existing Emacs infrastructure

**Alternatives Considered:**
- External org parser: Adds new dependency
- Grep-based validation: Could miss malformed org that still has TODO keywords

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| LLM API costs | Each run costs ~3 API calls | Suite is never automated; requires explicit operator invocation |
| Flaky timing | Poll timeouts could be too short | Generous timeouts (90s daemon, 120s tasks) |
| WebDAV race condition | tasks.org might not be immediately available | Poll with retries, save partial results |
| Container resource conflicts | Port 16065 might be in use | Clear error message, manual cleanup required |
| Network issues | LLM call could fail | Assertion fails with clear message, artifacts collected |
| Data pollution | test-data/ might have stale data | Wiped at script start, not end |

### Trade-offs

- **Debuggability vs. Speed**: Collecting all container logs and artifacts adds time but is essential for post-mortem. Worth the tradeoff.
- **Comprehensive Assertions vs. Cost**: Running all 3 assertions even if one fails slows down failure diagnosis but ensures complete picture. Worth it.
- **Strict Cleanup vs. Debug Data**: Keeping `test-data/` on exit for inspection means manual cleanup needed between runs. Intentional — data is useful for debugging.
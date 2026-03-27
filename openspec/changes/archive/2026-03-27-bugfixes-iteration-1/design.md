## Context

This change is a bounded reliability and safety bugfix iteration across three existing modules:
`sem-router.el`, `sem-core.el`, and `sem-git-sync.el`. The proposal defines four defects to fix
without introducing user-facing feature changes:

1. async task temp-file writes in router callbacks can bypass intended serialization,
2. debug logging in headline parsing uses a marker value where a number is required,
3. daily `*Messages*` flush appends duplicate unchanged content,
4. git-sync command execution uses shell-string command invocation.

The daemon is long-running and cron-invoked, so fixes must preserve current call flows,
must not crash public entry points, and must maintain existing log/error semantics.

## Goals / Non-Goals

**Goals:**
- Make task temp-file writes deterministic under concurrent async callbacks by routing all task writes through the existing mutex path.
- Ensure `sem-router--parse-headlines` debug logging cannot raise numeric-type errors.
- Prevent duplicate daily message log growth when `*Messages*` content is unchanged since the last successful flush.
- Replace shell-string command execution in git-sync with argv-based process execution while preserving exit-code and output behavior expected by callers.
- Keep behavior compatible with existing tests and cron entry points.

**Non-Goals:**
- No scheduler, cron, prompt/schema, WebDAV, or integration-test workflow changes.
- No new product features or data-model expansions.
- No redesign of git-sync authentication flow beyond command execution safety.

## Decisions

1. **Serialize async task temp writes through a single lock path in router**
   - Decision: ensure async task callbacks use `sem-router--with-tasks-write-lock` for the temp-file write section, retaining retry/DLQ behavior for lock contention.
   - Rationale: the lock utility already defines contention policy (`max retries`, delay, DLQ logging). Reusing it avoids parallel ad hoc write paths.
   - Alternatives considered:
     - Replace lock/retry with a queue worker: rejected for this iteration because it changes runtime architecture and ordering semantics.
     - Add file-level OS locks: rejected due to portability/complexity trade-off versus existing in-process lock mechanism.

2. **Fix parse debug logging to use numeric bounds correctly**
   - Decision: change the debug preview bound expression to use numeric positions (for example `(min (point-max) 100)`) and keep debug logging non-fatal.
   - Rationale: current expression mixes marker and numeric types in `min`, which can raise a runtime type error even in logging paths.
   - Alternatives considered:
     - Remove debug preview logging entirely: rejected because the diagnostic is useful during inbox parse issues.
     - Wrap only the logging line in `ignore-errors`: rejected as it masks a straightforward correctness bug.

3. **Introduce hash-based dedup in `sem-core--flush-messages-daily`**
   - Decision: track a content hash for the last successfully flushed `*Messages*` snapshot and skip append if hash is unchanged; reset dedup state appropriately on date rollover.
   - Rationale: current append-after-every-command behavior repeatedly writes identical content and grows logs unnecessarily.
   - Alternatives considered:
     - Track last flushed byte length: rejected because same length does not imply same content.
     - Truncate/rewrite daily file each flush: rejected because it changes existing append semantics and risks losing logs on partial failures.

4. **Use argv-based process execution in git-sync command runner**
   - Decision: replace shell-string execution with argv-based process APIs in `sem-git-sync--run-command` and update call sites to pass program + args.
   - Rationale: removes shell parsing/injection surface and makes argument handling deterministic.
   - Alternatives considered:
     - Keep shell command execution with manual quoting: rejected because quoting correctness is brittle and still shell-dependent.
     - Migrate to asynchronous process handling: rejected for this iteration to avoid broader flow changes.

## Risks / Trade-offs

- **[Lock path behavior drift]** Routing writes through mutex path could expose latent callback ordering assumptions -> **Mitigation:** keep existing retry counts/delays and add/adjust tests for concurrent callback scenarios.
- **[Dedup state edge cases]** Incorrect hash/date state transitions could suppress legitimate flushes -> **Mitigation:** update tests for first flush, unchanged content, changed content, and UTC date rollover.
- **[Git command parity]** Converting to argv calls may alter output text formatting slightly -> **Mitigation:** preserve captured stdout/stderr aggregation and keep caller checks on exit-code + non-empty output where needed.
- **[Scope creep]** Cross-module fixes can invite unrelated refactoring -> **Mitigation:** enforce bounded scope to the four proposal defects only.

## Migration Plan

1. Implement and test router lock-path and parse-debug fixes.
2. Implement and test message-flush hash dedup with rollover handling.
3. Refactor git-sync command execution to argv-based calls and validate existing sync flow behavior.
4. Run targeted ERT suites and lint (`dev/elisplint.sh`) for touched elisp files.
5. Deploy as normal daemon image update; rollback is safe by reverting this change set.

## Open Questions

- Should ssh-agent setup/teardown commands also be fully argv-mode with explicit env parsing helpers, or remain minimally adapted in this bugfix iteration?
- Do we want to persist message dedup hash across daemon restart, or keep it in-memory only for current process lifetime?

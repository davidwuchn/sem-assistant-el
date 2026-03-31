## Context

The daemon currently has correctness and maintenance issues concentrated in `sem-core.el`,
`sem-router.el`, `sem-planner.el`, `init.el`, and `Eask`. The biggest operational risk is
unbounded growth in cursor/retry state files and log-file write races from read-modify-write
logging. Additional issues include dead code (`error-count`, unused URL routing wrapper), an
unused dependency (`websocket`), and overly broad planner overlap windows caused by defaulting
missing timestamp end times to `23:59`.

The proposal requires a bounded daily purge model for cursor/retries, append-only log writes,
dead-code/dependency cleanup, and timestamp normalization that defaults missing end times to
start + 30 minutes (clamped to same-day `23:59`). The implementation must preserve daemon
resilience: failures in one purge sub-step must not crash or block other purge work.

## Goals / Non-Goals

**Goals:**
- Bound `.sem-cursor.el` growth by rebuilding it daily from currently active inbox headlines.
- Reset `.sem-retries.el` daily to keep retry state short-lived and operationally relevant.
- Make `sem-core-log` robust under concurrent writers by using append-only writes for entries.
- Remove dead code and unused dependency surface (`sem-router--route-to-url-capture`,
  `error-count`, `websocket`).
- Align planner overlap behavior with existing 30-minute normalization conventions.
- Keep all cron/public entry points resilient with isolated error handling.

**Non-Goals:**
- Redesigning inbox routing, retry policy, or DLQ semantics.
- Changing sensitive-content masking, LLM integration, RSS pipeline, or git-sync behavior.
- Refactoring unrelated modules or changing integration-test infrastructure.
- Introducing new storage formats for cursor/retry files.

## Decisions

1. Daily purge remains anchored to the existing 4AM purge window in `sem-core-purge-inbox`.
   - **Why:** Reuses an established maintenance window and avoids adding a new scheduler path.
   - **Alternative considered:** Purge on every inbox pass. Rejected due to unnecessary I/O and
     loss of useful same-day retry/cursor continuity.

2. Cursor purge strategy is rebuild-from-active-hashes, not incremental deletion.
   - **Why:** Deterministic, simple, and bounded by live inbox items; avoids stale-key drift.
   - **Alternative considered:** Track tombstones and delete selectively. Rejected as higher
     complexity with no practical benefit for tiny expected active sets.

3. Retries purge strategy is unconditional reset to empty alist at daily window.
   - **Why:** Retries are transient; stale entries beyond a day provide little value and increase
     file growth and lookup overhead.
   - **Alternative considered:** Age-based pruning per key. Rejected because retry timestamps are
     not first-class state today and would require schema expansion.

4. Logging entry writes switch to append-only `write-region ... append` after ensuring headings.
   - **Why:** Eliminates high-risk read-modify-write races on every log line while preserving
     existing heading structure.
   - **Alternative considered:** File locks around full-file rewrite. Rejected as brittle and more
     complex than append-only for the daemon's short-line log workload.

5. Keep `sem-core--ensure-log-headings` behavior unchanged.
   - **Why:** It already guarantees year/month/day scaffolding and only mutates when headings are
     missing; this keeps scope tight and minimizes regression risk.
   - **Alternative considered:** Rewriting heading management to fully append-oriented model.
     Rejected as unnecessary for this change.

6. Timestamp default end-time is computed in `sem-planner--parse-timestamp` for both string and
   org-element (`consp`) inputs as `start + 30min`, clamped to `23:59`.
   - **Why:** Centralizes default semantics at parse layer and keeps downstream range conversion
     deterministic.
   - **Alternative considered:** Preserve parse nils and default later in epoch conversion.
     Rejected because split defaults caused inconsistency and false overlap behavior.

7. Remove dead router wrapper and `error-count` telemetry field.
   - **Why:** Reduces maintenance noise and prevents misleading "Errors=0" reporting.
   - **Alternative considered:** Keep field and increment via DLQ/RETRY paths. Rejected because
     error visibility already exists in structured logs and `errors.org`.

8. Remove `websocket` from dependency/load path and adjust init tests accordingly.
   - **Why:** No runtime references exist; keeping it increases install surface and test burden.
   - **Alternative considered:** Keep optional dependency for future use. Rejected due to YAGNI and
     tighter supply-chain hygiene goals.

## Risks / Trade-offs

- [Append-only logs may not appear directly under day heading in unusual edited files] ->
  Mitigation: call `sem-core--ensure-log-headings` before each append; rely on chronological
  heading creation during normal daemon operation.
- [Cursor purge bug could drop hashes for still-active inbox headlines] -> Mitigation: derive hash
  list during same parse pass used to build kept headlines; add focused tests for keep/remove cases.
- [Retry reset may reprocess items that had long-running transient failures] -> Mitigation: accept
  intentional daily reset; DLQ and error logs retain failure history.
- [Timestamp default changes may alter planner behavior in existing edge cases] -> Mitigation: add
  explicit overlap/non-overlap tests for no-end-time schedules and same-day clamping.
- [Concurrent heading creation could produce duplicate headings] -> Mitigation: accept cosmetic
  duplication risk as preferable to lost log lines; no data loss in appended entries.

## Migration Plan

1. Implement code changes module-by-module (`sem-core`, `sem-router`, `sem-planner`, `init.el`,
   `Eask`) with tests updated in lockstep.
2. Run targeted ERT tests for modified modules, then full suite via repository test runner.
3. Deploy as normal daemon update; no state migration script required.
4. On first 4AM window post-deploy, cursor/retries files are compacted/reset automatically.
5. Rollback strategy: revert commit(s) if regressions appear; state files remain valid Elisp alists
   under both old and new behavior.

## Open Questions

- Should daily retries reset eventually become configurable (for operators who want multi-day
  transient retry memory), or remain hardcoded as an intentional policy?
- Do we want a follow-up low-priority cleanup to deduplicate log headings if concurrent creation
  ever causes visible cosmetic duplication?

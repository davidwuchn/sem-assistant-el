## Context

The current task LLM pipeline (`sem-router.el`) processes inbox items one-by-one, calling the LLM for each item and writing directly to `tasks.org` after each response. The LLM guesses scheduling attributes (SCHEDULED, DEADLINE, PRIORITY) with no awareness of:
- The user's existing commitments and time blocks
- User-defined scheduling preferences ("no work on weekends", "free after 4PM")
- Other tasks being processed in the same batch

This leads to scheduling conflicts, overbooking, and tasks scheduled at times that violate user preferences.

The change introduces a **two-pass scheduling architecture** with a rules file for user preferences and a batch planning step.

## Goals / Non-Goals

**Goals:**
- Enable users to express scheduling preferences in natural language via a rules file
- Reduce scheduling conflicts and preference violations by planning tasks holistically
- Support concurrent inbox processing without file write conflicts
- Handle LLM failures gracefully with fallback to provisional timing
- Allow rules to be updated without daemon restart

**Non-Goals:**
- Cross-day task scheduling (LLM schedules within available free time per day only)
- User-facing UI for editing rules (manual org-mode editing via WebDAV only)
- Changing the cron interval (still every 30 min)
- Changes to URL capture, elfeed, RSS digest, or inbox purge flows
- Hard validation of scheduling conflicts (soft preference, overlaps allowed)

## Decisions

### 1. Rules file location: `/data/rules.org`

**Decision:** Place the rules file at `/data/rules.org`, co-located with `inbox-mobile.org` and `tasks.org`.

**Rationale:** The `/data/` directory is already synced via WebDAV and accessible from mobile. Users can edit it the same way they edit inbox items. Co-location keeps the sync mechanism simple and consistent.

**Alternative considered:** Separate config directory or Git-managed config file. Rejected because WebDAV sync is already working for `/data/` and adding a new sync target adds complexity.

### 2. Two-pass vs single-pass with full context

**Decision:** Use two passes instead of injecting all existing tasks into a single LLM call.

**Rationale:**
- Existing tasks can be many (months/years of data). A single prompt with all tasks would hit token limits and be expensive.
- Pass 1 gets provisional timing guesses quickly, enabling fast first-pass results.
- Pass 2 anonymizes and summarizes existing schedule, providing enough context for good planning without full detail.
- Two passes allow retry at the planning stage without re-running all Pass 1 LLM calls.

**Alternative considered:** Single pass with summarized schedule. Rejected because the two-pass separation provides cleaner retry semantics and separates concerns (guess vs plan).

### 3. Batch temp file: `/tmp/data/tasks-tmp-{batch-id}.org`

**Decision:** Write Pass 1 results to a temp file named with the batch ID at `/tmp/data/`, not directly to `tasks.org`.

**Rationale:**
- Avoids write conflicts during concurrent Pass 1 processing
- Provides a clean input for Pass 2 (all provisional tasks in one file)
- Batch ID (monotonically increasing counter) ensures unique filenames and enables cleanup of stale files
- Temp file uses same org-mode format as `tasks.org`, so Pass 2 can read it as additional schedule context
- Using `/tmp/data/` keeps temp files ephemeral (cleaned up on container restart) but still provides persistence within a daemon session

**Alternative considered:** In-memory list. Rejected because crash recovery would lose all provisional tasks. File persistence is safer for a daemon that may crash mid-batch.

### 4. Count-based barrier with `sem-core--pending-callbacks`

**Decision:** Use a simple counter (`sem-core--pending-callbacks`) that decrements on each callback completion. When it reaches 0, fire the planning step.

**Rationale:**
- Minimal additional state — just one counter
- Natural fit for the existing callback pattern in `sem-router.el`
- Easy to understand and debug

**Alternative considered:** Event emitter / pub-sub. Overkill for this use case; adds unnecessary indirection.

### 5. Queueing concurrent batches with same `batch-id`

**Decision:** If a new cron run fires while planning is in progress, new inbox items are added to the current batch with the same `batch-id`. Pending count grows. Only one planning step runs at a time (implicit lock via not incrementing `batch-id`).

**Rationale:**
- Simpler than managing multiple concurrent planning steps
- Avoids planning step starvation or priority inversion
- Items naturally queue up; the planning step will include them on next run

**Alternative considered:** Increment `batch-id` for each cron run, run multiple planning steps concurrently. Rejected — concurrent planning steps would require coordination to avoid double-scheduling, adding significant complexity.

### 6. Anonymization format: `YYYY-MM-DD HH:MM-HH:MM busy PRIORITY:{A|B|C} TAG:{...}`

**Decision:** When building the Pass 2 prompt, anonymize existing tasks to time blocks with priority and filetag only. No titles, IDs, or descriptions.

**Rationale:**
- Privacy: task titles and descriptions may be sensitive
- Token efficiency: compact format minimizes prompt size
- Sufficient context: time blocks + priority + tag gives LLM enough to reason about availability

**Alternative considered:** Include task titles. Rejected — titles can be long and may contain sensitive information. Priority + tag is sufficient for scheduling decisions.

### 7. Atomic tasks.org append with re-read

**Decision:** Before appending final planned tasks, re-read `tasks.org` to get the latest state (in case it changed via WebDAV). Append merged tasks to end of tasks.org atomically using write-to-temp-then-rename pattern.

**Rationale:**
- WebDAV edits may happen concurrent with our processing
- Re-read ensures we don't clobber concurrent changes
- Append (not replace) preserves existing tasks
- Atomic rename ensures readers never see partial writes
- This pattern is already used elsewhere in the codebase (e.g., inbox writing)

**Alternative considered:** File locking. More complex, not supported on all filesystems, and rename is simpler.

### 8. Exclude `batch-id` increment during planning phase

**Decision:** `sem-core--batch-id` only increments at the start of a cron-triggered `sem-core-process-inbox`. During planning phase, new cron runs do NOT increment it.

**Rationale:**
- Creates an implicit lock: only one planning step runs at a time
- New items queue to current batch naturally
- No explicit lock acquisition/release complexity

**Alternative considered:** Explicit lock file. Adds filesystem overhead and potential for stale lock cleanup issues.

## Risks / Trade-offs

1. **Planning step LLM failure → fallback to Pass 1 timing**
   - **Risk:** If Pass 2 LLM fails after 3 retries, tasks are scheduled with provisional timing, which may violate user preferences.
   - **Mitigation:** Log error with `sem-core-log-error` module `planner`. Tasks are still usable, just possibly suboptimal. Human can reschedule manually.

2. **Daemon crash leaves stale temp files**
   - **Risk:** If daemon crashes during planning, `tasks-tmp-{batch-id}.org` files remain.
   - **Mitigation:** Startup cleanup removes `tasks-tmp-*.org` files older than 24 hours. Manual cleanup also trivial (just delete the files).

3. **Rules file ignored if contains conflicting preferences**
   - **Risk:** If rules are contradictory or ambiguous, LLM may make unexpected scheduling decisions.
   - **Mitigation:** Rules are plain text, human-editable. Users can correct contradictions. Pass 1 still provides provisional timing even without valid rules.

4. **Pass 1 provisional timing may influence Pass 2**
   - **Risk:** LLM may anchor on Pass 1 provisional times and not fully re-optimize.
   - **Mitigation:** Pass 2 prompt instructs LLM to re-schedule freely. The anonymized schedule does not include Pass 1 provisional times, so there's no anchoring data provided.

5. **Single-threaded planning step is a bottleneck**
   - **Risk:** If planning step takes > 30 min (cron interval), new items queue up.
   - **Mitigation:** This is explicitly acceptable per the design (see Edge Case 7). The implicit lock prevents thundering herd. If planning consistently takes > 30 min, the system is overloaded and needs design review.

6. **SCHEDULED format inconsistency between passes**
   - **Risk:** Pass 1 uses time ranges `SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>`, Pass 2 uses single times.
   - **Mitigation:** This is intentional. Pass 2 collapses/adjusts ranges as needed. Integration test patterns must account for both formats.

## Migration Plan

### Phase 1: New modules (no behavior change)
1. Create `sem-rules.el` — `sem-rules-read` returns rules text or nil
2. Create `sem-planner.el` — stub with `sem-planner-run-planning-step` that does nothing (or logs "not yet implemented")
3. Add `sem-core--batch-id` and `sem-core--pending-callbacks` state variables
4. At this point, inbox processing is unchanged

### Phase 2: Pass 1 updates (still no final write)
5. Update pass 1 prompt to inject rules and ask for time range
6. Write Pass 1 results to temp file instead of `tasks.org`
7. Route still calls LLM, but results go to temp file
8. At this point, no tasks are written to `tasks.org` (nothing is finalized)

### Phase 3: Batch barrier
9. Implement `sem-core--batch-barrier-check`
10. Call planning step when pending count reaches 0
11. Planning step still does nothing (stub)

### Phase 4: Planning step implementation
12. Implement `sem-planner--anonymize-tasks`
13. Implement `sem-planner-run-planning-step` with LLM call
14. Implement retry with exponential backoff
15. Implement atomic `tasks.org` update

### Phase 5: Cleanup and integration
16. Add startup cleanup for stale temp files
17. Integration tests with rules.org fixture
18. Update existing tests as needed

**Rollback:** If issues are found after Phase 4, revert to Phase 1 (stubs) or disable the planning step via feature flag. The old single-pass behavior can be preserved by having `sem-router--write-task-to-file` still write directly to `tasks.org` alongside temp file writes.

## Edge Cases

1. **rules.org does not exist**: Pass 1 uses no rules. Pass 2 skips rules section in prompt. System degrades to current behavior.

2. **rules.org is empty**: Treated as does not exist.

3. **No @task items in batch**: Batch barrier fires immediately with 0 items. Planning step is skipped. `sem-core--pending-callbacks` starts at 0, so `sem-core--batch-barrier-check` is called synchronously.

4. **Only @link items in batch**: No Pass 1 tasks, but URL capture callbacks still count toward pending. Barrier fires when all URL captures complete. Planning step receives 0 tasks, skips LLM call, writes nothing.

5. **Planning step LLM failure (all 3 retries exhausted)**: Tasks are written to tasks.org with provisional (Pass 1) timing. Error is logged with `sem-core-log-error` module `planner`. Batch temp file is deleted.

6. **Concurrent batch (cron fires during planning)**: Items queue to current batch. `sem-core--batch-id` does NOT increment. Pending count grows. Planning step for current batch includes all queued items.

7. **Planning step takes longer than 30 min (cron interval)**: The lock is held implicitly by not incrementing batch-id. New cron runs queue items. Only one planning step runs at a time.

8. **Daemon crashes during planning**: Temp batch file remains on next startup. Startup cleanup removes stale `tasks-tmp-*.org` files older than 24 hours.

9. **tasks.org does not exist during Pass 2**: Anonymization returns empty schedule. LLM schedules all tasks as new. Final atomic write creates tasks.org.

10. **Temp file write failure during Pass 1**: Callback logs error, marks item as DLQ. Other items continue. Barrier may never fire if count never reaches 0. A timeout watchdog (30 min from batch start) fires planning step regardless.

11. **LLM returns invalid org in Pass 2 response**: Treated as LLM failure. Retry with backoff.

12. **LLM returns time conflicts in Pass 2**: Soft preference — overlaps allowed but LLM is instructed to minimize them. No hard validation.

13. **SCHEDULED format in Pass 1 vs Pass 2**: Pass 1 uses `SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>` (time range). Pass 2 outputs simple scheduling decisions in format `ID: <uuid> | SCHEDULED: <timestamp>` or `ID: <uuid> | (unscheduled)`. These decisions are then merged into the full task bodies from Pass 1 temp file.

## Out of Scope

- Changes to the cron schedule (still every 30 min)
- Changes to @link URL capture flow
- Changes to elfeed update or RSS digest scheduling
- Changes to inbox purge (4AM window)
- User-facing UI for editing rules (manual org-mode editing via WebDAV only)
- Scheduling tasks across multiple days (LLM schedules within available free time on a per-day basis)

## Impact

- `sem-router--write-task-to-file` is no longer called after each LLM callback; writes go to temp batch file instead
- `sem-core-process-inbox` now manages batch lifecycle instead of fire-and-forget
- No mutex is used for tasks.org writes; the atomic `rename-file` pattern provides sufficient safety
- `sem-core-log` MODULE value `planner` added for planning step events
- Integration test assertions must account for SCHEDULED time range format (not just date)
- Integration test inbox-tasks.org may need a rules.org fixture for Pass 2 testing
- Before atomic update, tasks.org is re-read to get the latest state — this handles concurrent WebDAV edits

## Integration Test Changes

1. **test-data/rules.org fixture**: Create `dev/integration/testing-resources/rules.org` with test preferences:
   ```
   * Test Scheduling Rules
   Routine tasks are best scheduled in the afternoon.
   Work tasks should not be scheduled on weekends.
   ```
   Copy to test-data directory during setup.

2. **inbox-tasks.org assertions**: After Pass 2, tasks must have SCHEDULED with time (not just date). Update assertion grep patterns if needed.

3. **New assertion (Assertion 5)**: Validate that at least some tasks have SCHEDULED times that fall within "preferred" windows defined in rules.org. Soft check — log result, do not fail.

4. **tasks-tmp cleanup**: On test startup, remove any stale `tasks-tmp-*.org` files from previous runs.

## Tests to Create

| Test File | What It Tests |
|-----------|---------------|
| `sem-rules-test.el` | `sem-rules-read` returns nil if file missing, returns string if file exists and non-empty |
| `sem-planner-test.el` | `sem-planner--anonymize-tasks` strips titles/IDs, preserves time+priority+tag |
| `sem-planner-test.el` | `sem-planner--batch-barrier-check` fires when pending count reaches 0 |
| `sem-planner-test.el` | `sem-planner-run-planning-step` retries up to 3 times on LLM failure |
| `sem-planner-test.el` | `sem-planner-run-planning-step` falls back to Pass 1 timing after all retries exhausted |
| `sem-planner-test.el` | `sem-planner--atomic-tasks-org-update` uses rename-file over write-region |

## Open Questions

1. **Temp file cleanup timing:** Should cleanup run on every daemon startup, or only on certain conditions? Currently: on startup. Open to feedback.

2. **Pass 2 prompt engineering:** The proposal says "Default planning prompt: 'schedule tasks'". Is this sufficient, or should the prompt be more elaborate with examples of good scheduling?

3. **rules.org format validation:** Should `sem-rules-read` validate the rules file format? If so, what constitutes a valid rules file?

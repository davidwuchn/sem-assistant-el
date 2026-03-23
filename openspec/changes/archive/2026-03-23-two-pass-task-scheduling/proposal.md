## Why

The current task LLM pipeline has the LLM guess scheduling attributes (SCHEDULED, DEADLINE, PRIORITY) in isolation, with no awareness of the user's existing commitments or preferences. The result is tasks that may not fit the user's actual free time, or scheduling decisions that ignore user rules (e.g., "I'm free for routine tasks after 4PM", "no work tasks on weekends").

## What Changes

1. **Rules file** (`/data/rules.org`) — user preferences for scheduling, editable via WebDAV from mobile
2. **Two-pass scheduling** — Pass 1 (LLM guesses provisional time range) → temp file → Pass 2 (LLM plans into free time)
3. **sem-rules.el** — new module to read/parse rules.org (read at call time, no daemon restart needed)
4. **sem-planner.el** — new module for planning step (batch barrier, anonymization, planning LLM call, atomic tasks.org update with re-read)
5. **Batch tracking** — count-based barrier with queueing for concurrent inbox items
6. **Updated pass 1 prompt** — injects rules, asks for time range guess
7. **Atomic tasks.org update with re-read** — before updating tasks.org, re-read it to get the latest state, then write all tasks atomically

## Capabilities

### New Capabilities

- **rules-org**: User preferences file at `/data/rules.org`. Plain text, natural language rules that the LLM uses for scheduling decisions. Example content:
  ```
  * My Scheduling Preferences

  I'm free for routine tasks usually from 16:00 PM.
  I prefer do not do work things on weekend.
  Family tasks can be scheduled any time.
  ```
  Synced via WebDAV (same mechanism as inbox-mobile.org and tasks.org).

- **sem-rules-el**: New module `app/elisp/sem-rules.el`. Provides `sem-rules-read` that parses rules.org and returns rules text (string) or nil if file does not exist. Has no runtime dependencies on other sem-* modules.

- **two-pass-scheduling**: Pass 1 generates provisional task entries with guessed time ranges; Pass 2 reads all temp tasks + rules + anonymized existing schedule, then re-schedules into actual free time. Retry Pass 2 up to 3 times with exponential backoff on LLM failure. Default planning prompt: "schedule tasks". On all retries exhausted, write tasks with provisional timing (Pass 1 results) and log error.

- **batch-temp-file**: During Pass 1, each task in the batch is written to a temp file `/tmp/data/tasks-tmp-{batch-id}.org` instead of tasks.org. The temp file uses the same org-mode TODO format as tasks.org. Batch ID is a monotonically increasing counter (`sem-core--batch-id`).

- **batch-barrier**: Count-based barrier that fires the planning step when `sem-core--pending-callbacks` reaches 0. Implemented in `sem-core--batch-barrier-check` called by each callback on completion.

- **inbox-queue-during-batch**: If a new cron run fires while a batch is in planning phase, new inbox items are added to the current batch. The pending callback count is incremented for each new item. Items are appended to the same temp file.

- **schedule-anonymization**: When building the Pass 2 planning prompt, existing tasks.org tasks are anonymized to the format:
  ```
  YYYY-MM-DD HH:MM-HH:MM busy PRIORITY:{A|B|C} TAG:{work|family|routine|opensource}
  ```
  No task titles, IDs, or descriptions are included. Only time blocks with priority and filetag.

- **atomic-tasks-org-update**: After Pass 2 completes and merge step finishes, re-read tasks.org to get the latest state (in case it changed since batch started), then append merged tasks to the end of tasks.org atomically using write-to-temp-then-rename pattern.

- **rules-reload-on-each-batch**: `rules.org` is read fresh before every batch (at the start of `sem-core-process-inbox`). No daemon restart needed. Simply a file read at call time.

### Modified Capabilities

- **task-llm-pipeline**: Pass 1 prompt updated to:
  - Inject rules text from rules.org
  - Ask LLM to guess a provisional time range in format `SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>`
  - Rules are prepended to the user prompt section
  - If rules.org does not exist, pass 1 prompt is unchanged from current behavior
  - The provisional SCHEDULED is a hint only; Pass 2 may override it

- **inbox-processing**: Modified to:
  - Increment `sem-core--batch-id` at start of each cron-triggered `sem-core-process-inbox`
  - Track `sem-core--pending-callbacks` for each routed item
  - Write Pass 1 results to batch temp file instead of tasks.org
  - Call `sem-planner-run-planning-step` when pending count reaches 0

- **sem-prompts-org-mode-cheat-sheet**: Add SCHEDULED time range format to the cheat sheet:
  ```
  SCHEDULED: <YYYY-MM-DD Day> or SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>
  ```

## Impact

- `sem-router--write-task-to-file` is no longer called after each LLM callback; writes go to temp batch file instead
- `sem-core-process-inbox` now manages batch lifecycle instead of fire-and-forget
- No mutex is used for tasks.org writes; the atomic `rename-file` pattern provides sufficient safety
- `sem-core-log` MODULE value `planner` added for planning step events
- Integration test assertions must account for SCHEDULED time range format (not just date)
- Integration test inbox-tasks.org may need a rules.org fixture for Pass 2 testing
- Before atomic update, tasks.org is re-read to get the latest state — this handles concurrent WebDAV edits

## Edge Cases

1. **rules.org does not exist**: Pass 1 uses no rules. Pass 2 skips rules section in prompt. System degrades to current behavior.

2. **rules.org is empty**: Treated as does not exist.

3. **No @task items in batch**: Batch barrier fires immediately with 0 items. Planning step is skipped. `sem-core--pending-callbacks` starts at 0, so `sem-core--batch-barrier-check` is called synchronously.

4. **Only @link items in batch**: No Pass 1 tasks, but URL capture callbacks still count toward pending. Barrier fires when all URL captures complete. Planning step receives 0 tasks, skips LLM call, writes nothing.

5. **Planning step LLM failure (all 3 retries exhausted)**: Tasks are written to tasks.org with provisional (Pass 1) timing. Error is logged with `sem-core-log-error` module `planner`. Batch temp file is deleted.

6. **Concurrent batch (cron fires during planning)**: Items queue to current batch. `sem-core--batch-id` does NOT increment. Pending count grows. Planning step for current batch includes all queued items.

7. **Planning step takes longer than 30 min (cron interval)**: The lock is held implicitly by not incrementing batch-id. New cron runs queue items. Only one planning step runs at a time.

8. **Daemon crashes during planning**: Temp batch file remains on next startup. Startup cleanup should remove stale `tasks-tmp-*.org` files older than 24 hours.

9. **tasks.org does not exist during Pass 2**: Anonymization returns empty schedule. LLM schedules all tasks as new. Final atomic write creates tasks.org.

10. **Temp file write failure during Pass 1**: Callback logs error, marks item as DLQ. Other items continue. Barrier may never fire if count never reaches 0. A timeout watchdog (30 min from batch start) should fire planning step regardless.

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

## Specs to Update

| Spec | Change |
|------|--------|
| `task-llm-pipeline/spec.md` | Add pass 1 prompt rules injection, provisional time range, temp file write |
| `inbox-processing/spec.md` | Add batch tracking, barrier, queueing |
| `sem-prompts-org-mode-cheat-sheet/spec.md` | Add SCHEDULED time range format |
| `cron-scheduling/spec.md` | No change (planning step is internal, no new cron entry) |

## Tests to Pass (Existing)

- `sem-router-test.el` — `sem-router--validate-task-response` continues to pass (format unchanged)
- `sem-router-test.el` — `sem-router--write-task-to-file` continues to pass (file creation, append, tag normalization)
- `sem-core-test.el` — cursor tracking tests pass
- `sem-prompts-test.el` — cheat sheet constant exists and has no format specifiers

## Tests to Modify

| Test File | What Changes |
|-----------|-------------|
| `sem-router-test.el` | Add tests for temp file writing (Pass 1 → temp file instead of tasks.org) |
| `sem-router-test.el` | Add tests for `sem-router--validate-task-response` with SCHEDULED time range format |
| `sem-prompts-test.el` | Add test that cheat sheet includes SCHEDULED time range format |

## Tests to Create

| Test File | What It Tests |
|-----------|---------------|
| `sem-rules-test.el` | `sem-rules-read` returns nil if file missing, returns string if file exists and non-empty |
| `sem-planner-test.el` | `sem-planner--anonymize-tasks` strips titles/IDs, preserves time+priority+tag |
| `sem-planner-test.el` | `sem-planner--batch-barrier-check` fires when pending count reaches 0 |
| `sem-planner-test.el` | `sem-planner-run-planning-step` retries up to 3 times on LLM failure |
| `sem-planner-test.el` | `sem-planner-run-planning-step` falls back to Pass 1 timing after all retries exhausted |
| `sem-planner-test.el` | `sem-planner--atomic-tasks-org-update` uses rename-file over write-region |

## Integration Test Changes

1. **test-data/rules.org fixture**: Create `dev/integration/testing-resources/rules.org` with test preferences:
   ```
   * Test Scheduling Rules
   Routine tasks are best scheduled in the afternoon.
   Work tasks should not be scheduled on weekends.
   ```
   Copy to test-data directory during setup.

2. **inbox-tasks.org assertions**: After Pass 2, tasks must have SCHEDULED with time (not just date). Update assertion grep patterns if needed.

3. **New assertion (Assertion 5)**: Validate that at least some tasks have SCHEDULED times that fall within "preferred" windows defined in rules.org. This is a soft check — just log result, do not fail.

4. **tasks-tmp cleanup**: On test startup, remove any stale `tasks-tmp-*.org` files from previous runs.

# Proposal: Cursor/Retries Purge and Dead Code Cleanup

## Why

Six independent correctness and hygiene defects accumulated during vibe-coded development:

1. **Unbounded cursor/retries state files.** `.sem-cursor.el` and `.sem-retries.el` grow monotonically: every processed headline appends a SHA-256 hash that is never removed. After months of 30-minute cron cycles the files contain thousands of entries. Every `sem-core--is-processed` call performs a full file read + Elisp `read` + alist scan. Performance degrades linearly with history length, and the files serve no purpose beyond "was this headline already seen in recent batches." Items that reached DLQ and were not manually fixed are not important enough to retain.

2. **Dead `error-count` variable.** `sem-router-process-inbox` (sem-router.el, line ~744) declares `(error-count 0)` and logs it at the end, but no code path ever increments it. The final log line `Errors=%d` is always `0`, which is misleading — errors do occur but are counted via the DLQ/RETRY log entries instead.

3. **Dead `sem-router--route-to-url-capture` function.** Defined at sem-router.el lines 213-236. The actual URL routing in `sem-router-process-inbox` (line ~769) calls `sem-url-capture-process` directly with an inline callback. The wrapper function is never called from anywhere.

4. **Unused `websocket` dependency.** The Eask manifest declares `(depends-on "websocket")` but no Elisp module references any websocket function or variable. This adds build time and attack surface for no benefit. Likely a leftover from a removed or never-implemented feature.

5. **Log file corruption risk under concurrent writes.** `sem-core-log` reads the entire log file into a temp buffer, finds the day heading via regex, inserts a line, and writes back the full file. Two cron jobs firing simultaneously (e.g., inbox processing at `:30` and the watchdog at `:30`) perform this read-modify-write without any coordination. Possible outcomes: duplicate entries, lost entries, or a malformed org file. The risk is low today (most cron jobs don't overlap) but will bite eventually.

6. **Timestamp end-time default causes false overlap conflicts.** `sem-planner--parse-timestamp` defaults missing end-time components to `hour=23, minute=59`. This means any task with a start time but no end time (e.g., `<2026-04-01 Wed 09:00>`) is treated as occupying `09:00-23:59` during overlap detection. The planner then flags false conflicts with every other task scheduled that day.

## What Changes

- `sem-core-purge-inbox` is extended to also purge `.sem-cursor.el` and `.sem-retries.el` during the existing 4AM daily window. The purge rebuilds the cursor file to contain only hashes of headlines that are still present (unprocessed) in `inbox-mobile.org` after the inbox purge. The retries file is unconditionally reset to an empty alist — any item that survived 24+ hours of retries without resolution is not worth tracking.

- The dead `error-count` variable is removed from `sem-router-process-inbox`. The log line format changes from `Processed=%d, Skipped=%d, Errors=%d` to `Processed=%d, Skipped=%d`.

- The dead `sem-router--route-to-url-capture` function is deleted entirely from `sem-router.el`.

- The `(depends-on "websocket")` line is removed from `Eask`. The `(require 'websocket)` in `init.el` (if present) is also removed.

- `sem-core-log` is modified to use an append-only write strategy instead of read-modify-write. On each call, the function appends only the new log line to the end of the file. The heading structure (year/month/day) is maintained by `sem-core--ensure-log-headings`, which is the only function that performs read-modify-write — and it only creates missing headings, so concurrent calls that both create the same heading are harmless (idempotent insert). The log entry itself is a single `write-region ... append` call, which is atomic at the OS level for short writes.

- `sem-planner--parse-timestamp` is modified to default missing end-time to start-time + 30 minutes (matching the existing `sem-router--normalize-scheduled-duration` default) instead of `23:59`. This aligns the overlap detection window with the actual scheduled duration convention used throughout the system.

## Capabilities

### New Capabilities

- `cursor-daily-purge`: During the existing 4AM purge window, after inbox purge completes, `.sem-cursor.el` is rebuilt. The new cursor contains only hashes of headlines that remain in `inbox-mobile.org` after the inbox purge (i.e., unprocessed headlines that were kept). All other hashes are discarded. This bounds cursor file size to at most the number of unprocessed inbox items (typically 0-10), rather than growing unboundedly with history.

- `retries-daily-purge`: During the same 4AM purge window, `.sem-retries.el` is unconditionally reset to `()` (empty alist). Rationale: retries exist to handle transient API failures within a single day. Any item that has been retrying for 24+ hours without resolution either hit DLQ (and was logged to errors.org) or will be re-encountered on the next inbox processing cycle. There is no value in preserving stale retry counts across days.

### Modified Capabilities

- `sem-core-purge-inbox`: Gains two additional steps after the existing inbox purge: (1) rebuild cursor, (2) reset retries. Both steps are wrapped in their own `condition-case` so a failure in cursor/retries purge does not prevent inbox purge from succeeding. The 4AM hour guard applies to all three steps.

- `sem-core-log` (structured logging): The function body changes from read-file/find-heading/insert/write-file to: (1) call `sem-core--ensure-log-headings` to guarantee heading structure exists, (2) format the log line string, (3) append the log line to the file via `write-region content nil log-file t 'silent` (append mode). The heading-finding logic is removed from `sem-core-log` itself. The `sem-core--ensure-log-headings` function is unchanged — it still performs read-modify-write, but only to create missing headings (year/month/day), which is idempotent.

- `sem-planner--parse-timestamp`: The fallback for missing end-time changes from `(hour-end 23, minute-end 59)` to computing end-time as start-time + 30 minutes. Specifically: when `(match-string 6 ts)` is nil (no end-hour in timestamp), set `hour-end` to the hour component and `minute-end` to the minute component of `(start-hour * 60 + start-minute + 30)` minutes, with hour overflow handled (e.g., 23:45 start -> 00:15 end, but capped to same-day 23:59 if it would cross midnight).

- `sem-router-process-inbox`: The `error-count` binding and its reference in the final log format string are removed.

### Removed Capabilities

- `sem-router--route-to-url-capture`: Deleted. No callers exist.
- `websocket` Eask dependency: Removed. No code references it.

## Impact

### Test command

All tests are run with:
```
emacs --batch --load app/elisp/tests/sem-test-runner.el
```
Zero test failures are required. Pre-existing passing tests must not regress.

### Test files: MUST be modified

**`sem-core-test.el`**:
- Add new tests for cursor purge behavior:
  - (a) After purge, cursor file contains only hashes of headlines that remain in inbox-mobile.org.
  - (b) After purge, cursor file does NOT contain hashes of headlines that were removed from inbox-mobile.org.
  - (c) Retries file is empty after purge.
  - (d) Cursor/retries purge does not run outside 4AM window.
  - (e) If cursor purge fails, inbox purge result is not affected (error isolation).
- Update any existing tests that assert the exact format of `sem-core-log` output if the append-only change affects them. Specifically: log entries will now appear at end of file rather than immediately after the day heading. Tests that assert log entry position relative to headings must be updated.

**`sem-router-test.el`**:
- Remove or update any tests that reference `sem-router--route-to-url-capture`.
- Remove or update any tests that assert `error-count` appears in log output. Update assertions for the new format string: `Processed=%d, Skipped=%d` (no Errors field).

**`sem-planner-test.el`**:
- Update tests that assert overlap detection behavior for timestamps without end-time. The expected overlap window changes from `start-23:59` to `start-(start+30min)`.
- Add a test: task scheduled at `<2026-04-01 Wed 09:00>` (no end time) should NOT overlap with a task at `<2026-04-01 Wed 14:00>` (previously would have overlapped due to 23:59 default).
- Add a test: task at `<2026-04-01 Wed 09:00>` SHOULD overlap with a task at `<2026-04-01 Wed 09:15>` (within 30-min window).

### Test files: MUST NOT be modified (must pass unchanged)

- `sem-security-test.el` — security module is unchanged
- `sem-llm-test.el` — gptel wrapper is unchanged
- `sem-async-test.el` — async return behavior is unchanged
- `sem-retry-test.el` — retry/DLQ logic is unchanged (retries file reset is in sem-core, not retry module)
- `sem-git-sync-test.el` — git sync is unchanged
- `sem-url-capture-test.el` — URL capture pipeline is unchanged
- `sem-url-sanitize-test.el` — URL defanging is unchanged
- `sem-init-test.el` — MUST be updated: the test at line 122-123 mocks a `websocket` load failure; remove that specific mock branch since websocket is no longer a dependency. The rest of the init tests must pass unchanged.
- `sem-rss-test.el` — RSS is unchanged
- `sem-prompts-test.el` — prompts are unchanged
- `sem-time-test.el` — time module is unchanged
- `sem-rules-test.el` — rules module is unchanged
- `sem-mock.el` — test mocks are unchanged
- `sem-webdav-config-test.el` — webdav config is unchanged

### Non-test files: MUST be modified

| File | Change |
|------|--------|
| `sem-core.el` | (1) Extend `sem-core-purge-inbox` with cursor rebuild + retries reset. (2) Rewrite `sem-core-log` to append-only strategy. |
| `sem-router.el` | (1) Delete `sem-router--route-to-url-capture`. (2) Remove `error-count` variable and its log reference from `sem-router-process-inbox`. |
| `sem-planner.el` | Change `sem-planner--parse-timestamp` end-time default from `23:59` to `start + 30 minutes`. |
| `Eask` | Remove `(depends-on "websocket")`. |
| `init.el` | Remove `websocket` from the package load list at line 111. |

### Non-test files: MUST NOT be modified
- `sem-security.el`, `sem-llm.el`, `sem-url-capture.el`, `sem-git-sync.el`, `sem-rss.el`, `sem-prompts.el`, `sem-time.el`, `sem-paths.el`, `sem-rules.el`
- `docker-compose.yml`, `Dockerfile.emacs`, `crontab`, `sem-assistant.el`
- `dev/start-cron`, `dev/sem-daemon-watchdog`
- `webdav/apache/start-webdav.sh`, `webdav/apache/httpd-webdav.conf.template`

## Approach

### 1. Cursor/Retries Purge (sem-core.el)

Add two new functions:

**`sem-core--purge-cursor-to-active-hashes (active-hashes)`**: Takes a list of SHA-256 hash strings (the hashes of headlines that remain in inbox-mobile.org after purge). Writes a new cursor file containing only these hashes. Uses the existing atomic temp-file + rename pattern from `sem-core--write-cursor`.

**`sem-core--purge-retries ()`**: Writes `()\n` to `.sem-retries.el` via the existing atomic write pattern.

Extend `sem-core-purge-inbox` to call both after the inbox purge step. The active hashes are already computed during the inbox purge loop — they are the hashes of headlines in the `keep-headlines` list. Collect these hashes into a list during the `org-element-map` pass and pass them to `sem-core--purge-cursor-to-active-hashes`.

**Implementation detail for the implementer**: In the existing purge loop at line ~552, when a headline is NOT processed (the `else` branch that pushes to `keep-headlines`), also push its `hash` to a new `keep-hashes` list. After the inbox purge atomic rename, call `(sem-core--purge-cursor-to-active-hashes keep-hashes)` and `(sem-core--purge-retries)`. Wrap each call in its own `condition-case` so failures are independent.

When inbox-mobile.org does not exist (the second `cond` branch at line ~538), still purge cursor and retries — if there's no inbox file, there are no active hashes, so cursor becomes empty and retries reset. This handles the edge case where all items were processed and the file was deleted externally.

When not in the 4AM window, do NOT purge cursor/retries (they only purge during the 4AM window, same as inbox).

### 2. Append-Only Logging (sem-core.el)

Rewrite `sem-core-log` body. The new flow:

1. Call `(sem-core--ensure-log-headings)`. If it returns nil, fall back to stderr (existing behavior).
2. Format the log line: `"- [HH:MM:SS] [module] [event-type] [status] tokens=NNN | message\n"`. Same format as today.
3. Append the single line to `sem-core-log-file` via `(write-region line nil sem-core-log-file t 'silent)`.

**Critical detail**: The log line must end with `\n`. The `write-region` with append flag (`t` as the 4th argument) appends to the end of the file. This means log entries will appear after the last day heading and after any previously appended entries. The heading structure is maintained by `sem-core--ensure-log-headings` which already creates year/month/day headings if missing.

**Trade-off the implementer must understand**: Log entries will always appear at the end of the file, not immediately under their day heading if multiple day headings exist. This is acceptable because: (a) the daemon runs continuously and headings are created in chronological order, so the last heading is always "today"; (b) if the daemon restarts mid-day, `ensure-log-headings` creates today's heading before any append. The only case where entries could appear under the wrong day is if the file is externally edited to add future-dated headings — this does not happen in practice.

**Do NOT change `sem-core--ensure-log-headings`**. It stays as-is with its read-modify-write pattern. It only runs once per log call, only writes when a heading is missing, and concurrent creation of the same heading is idempotent (duplicate heading is cosmetically ugly but not data-corrupting).

### 3. Dead Code Removal (sem-router.el)

**Remove `sem-router--route-to-url-capture`**: Delete the entire function definition (lines 213-236). No callers exist — verify with grep before deleting.

**Remove `error-count`**: In `sem-router-process-inbox`, remove `(error-count 0)` from the `let` binding. Change the final log format from:
```elisp
(format "Processed=%d, Skipped=%d, Errors=%d" processed-count skipped-count error-count)
```
to:
```elisp
(format "Processed=%d, Skipped=%d" processed-count skipped-count)
```
Also update the `message` call on the next line to match.

### 4. Websocket Removal (Eask)

Delete the line `(depends-on "websocket")` from the Eask file. In `init.el` line 111, remove `websocket` from the `dolist` package list: change `'(gptel elfeed elfeed-org org-roam websocket)` to `'(gptel elfeed elfeed-org org-roam)`. In `sem-init-test.el` lines 122-123, remove the mock branch that simulates a websocket load failure. No other Elisp files reference websocket.

### 5. Timestamp End-Time Default (sem-planner.el)

In `sem-planner--parse-timestamp`, replace the fallback logic for missing end-time. Current code (string branch, lines ~96-97):
```elisp
(if (match-string 6 ts) (string-to-number (match-string 6 ts)) 23)
(if (match-string 7 ts) (string-to-number (match-string 7 ts)) 59)
```

New logic:
```elisp
(if (match-string 6 ts)
    (string-to-number (match-string 6 ts))
  (let* ((start-total (+ (* start-hour 60) start-minute 30))
         (end-total (min start-total (+ (* 23 60) 59))))
    (/ end-total 60)))
(if (match-string 7 ts)
    (string-to-number (match-string 7 ts))
  (let* ((start-total (+ (* start-hour 60) start-minute 30))
         (end-total (min start-total (+ (* 23 60) 59))))
    (% end-total 60)))
```

**Important**: The `start-hour` and `start-minute` variables are already bound earlier in the same `let*` form (from match-strings 4 and 5). The `min` clamp ensures the end-time never exceeds 23:59 (no midnight rollover — tasks don't span days in this system).

**Also apply the same fix to the `consp` branch** (lines ~83-84), which uses `org-element-property :hour-end` and `:minute-end`. When these return nil, compute end = start + 30 minutes with the same clamping logic. Currently these nil cases also fall through to the caller which uses `(or (nth 5 parts) 23)` and `(or (nth 6 parts) 59)` in `sem-planner--timestamp-to-epoch-range` — but the fix should be in `parse-timestamp` itself so the default is consistent everywhere.

**Implementation detail**: Since the `consp` branch returns a flat list, the implementer needs to compute the fallback inline:
```elisp
;; For hour-end:
(or (org-element-property :hour-end ts)
    (let ((total (min (+ (* (org-element-property :hour-start ts) 60)
                          (org-element-property :minute-start ts) 30)
                      (+ (* 23 60) 59))))
      (/ total 60)))
;; For minute-end:
(or (org-element-property :minute-end ts)
    (let ((total (min (+ (* (org-element-property :hour-start ts) 60)
                          (org-element-property :minute-start ts) 30)
                      (+ (* 23 60) 59))))
      (% total 60)))
```

And correspondingly, remove the `(or (nth 5 parts) 23)` / `(or (nth 6 parts) 59)` fallbacks in `sem-planner--timestamp-to-epoch-range` — they should use the values directly from `parts` without further defaulting, since `parse-timestamp` now always returns concrete values.

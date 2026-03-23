## 1. Phase 1: New modules (no behavior change)

- [x] 1.1 Create `sem-rules.el` with `sem-rules-read` function that returns rules text or nil
- [x] 1.2 Create `sem-planner.el` stub with `sem-planner-run-planning-step` that logs "not yet implemented"
- [x] 1.3 Add `sem-core--batch-id` state variable to `sem-core.el`
- [x] 1.4 Add `sem-core--pending-callbacks` state variable to `sem-core.el`
- [x] 1.5 Add startup cleanup for stale `tasks-tmp-*.org` files older than 24 hours

## 2. Phase 2: Pass 1 updates (still no final write)

- [x] 2.1 Update Pass 1 prompt in `sem-prompts.el` to inject rules text and ask for time range `SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>`
- [x] 2.2 Update `sem-prompts.el` cheat sheet to include time range format documentation
- [x] 2.3 Modify `sem-router.el` to write Pass 1 results to temp file `/tmp/data/tasks-tmp-{batch-id}.org` instead of `tasks.org`
- [x] 2.4 Update `sem-router--write-task-to-file` to support temp file path parameter

## 3. Phase 3: Batch barrier

- [x] 3.1 Implement `sem-core--batch-barrier-check` function
- [x] 3.2 Call `sem-core--batch-barrier-check` from each callback on completion
- [x] 3.3 Implement synchronous barrier fire when `sem-core--pending-callbacks` starts at 0
- [x] 3.4 Connect barrier to invoke `sem-planner-run-planning-step` when counter reaches 0
- [x] 3.5 Implement timeout watchdog to fire planning step if barrier hasn't fired within 30 minutes of batch start

## 4. Phase 4: Planning step implementation

- [x] 4.1 Implement `sem-planner--anonymize-tasks` to strip titles/IDs, preserve time+priority+tag
- [x] 4.2 Implement Pass 2 prompt construction with anonymized schedule + rules + tasks
- [x] 4.3 Implement `sem-planner-run-planning-step` with LLM call and retry logic
- [x] 4.4 Implement exponential backoff: 1s, 2s, 4s on LLM failure (3 retries max)
- [x] 4.5 Implement fallback: write tasks with Pass 1 timing when all retries exhausted
- [x] 4.6 Implement `sem-planner--atomic-tasks-org-update` with re-read and rename
- [x] 4.7 Delete batch temp file after successful atomic update or fallback

## 5. Phase 5: Cleanup and integration

- [x] 5.1 Update `sem-router.el` to remove mutex from Pass 1 writes (no mutex needed - atomic rename provides sufficient safety)
- [x] 5.2 Create `sem-rules-test.el` tests for `sem-rules-read`
- [x] 5.3 Create `sem-planner-test.el` tests for anonymization, barrier, retry, atomic update
- [ ] 5.4 Update integration test inbox-tasks.org if needed for time range format assertions
- [x] 5.5 Add `dev/integration/testing-resources/rules.org` fixture for integration tests
- [x] 5.6 Add soft assertion (Assertion 5) in integration test to validate SCHEDULED times fall within preferred windows from rules.org

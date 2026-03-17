## 1. Fix Parse Crash in sem-router.el

- [x] 1.1 Wrap `sem-router--parse-headlines` body with `(cl-block sem-router--parse-headlines ...)` to support `cl-return-from`
- [x] 1.2 Verify no other logic changes in `sem-router--parse-headlines` beyond the `cl-block` wrapper

## 2. Implement Task LLM Pipeline in sem-router.el

- [x] 2.1 Create `sem-router--route-to-task-llm` function to handle `@task` headlines
- [x] 2.2 Add routing logic in `sem-router--route-headline` to detect `@task` tags and call the task LLM pipeline
- [x] 2.3 Implement LLM prompt for task processing that requests structured Org TODO output with `:PROPERTIES:` drawer and `:FILETAGS:`
- [x] 2.4 Add tag validation logic to check `:FILETAGS:` against `sem-router-task-tags` allowed list `("work" "family" "routine" "opensource")`
- [x] 2.5 Implement default tag substitution (`:routine:`) when LLM returns absent or invalid tag
- [x] 2.6 Add logic to create `/data/tasks.org` if it doesn't exist before appending
- [x] 2.7 Wire task LLM pipeline to use `sem-llm-request` with headline hash for cursor tracking

## 3. Fix Inbox Purge in sem-core.el

- [x] 3.1 Modify `sem-core-purge-inbox` to use region-based or org-element-based copy for unprocessed headlines
- [x] 3.2 Ensure full subtree preservation (title line + all body lines until next `* ` headline or EOF)
- [x] 3.3 Verify atomic rename behavior is maintained with temp file approach
- [x] 3.4 Add test that creates inbox with processed and unprocessed headlines (each with body lines) and asserts body is preserved after purge

## 4. Wire Security Masking in sem-url-capture.el

- [x] 4.1 Call `sem-security-sanitize-for-llm` on sanitized article text before passing to `sem-llm-request`
- [x] 4.2 Store returned `blocks` alist in context plist under `:security-blocks`
- [x] 4.3 Call `sem-security-sanitize-urls` on raw LLM response before passing to `sem-url-capture--validate-and-save`
- [x] 4.4 Ensure `sem-security-restore-from-llm` is explicitly NOT called in url-capture pipeline
- [x] 4.5 Add test asserting text passed to `sem-llm-request` has sensitive blocks tokenized
- [x] 4.6 Add test asserting LLM response passed to `validate-and-save` has URLs defanged (`hxxp://`)

## 5. Route RSS Digest Through sem-llm-request in sem-rss.el

- [x] 5.1 Replace direct `gptel-request` call in `sem-rss--generate-file` with `sem-llm-request`
- [x] 5.2 Pass `nil` as the `hash` argument to `sem-llm-request` (no per-entry cursor deduplication)
- [x] 5.3 Verify `sem-core--mark-processed` handles `nil` hash as a no-op without crashing
- [x] 5.4 Add error handling for malformed LLM output: log to `errors.org`, do not write output file
- [x] 5.5 Add error handling for API errors: log to `errors.org` with RETRY status, do not write output file
- [x] 5.6 Add test asserting `sem-rss--generate-file` invokes `sem-llm-request` (not `gptel-request`)

## 6. Add Tests for Parse Crash Fix

- [x] 6.1 Create test in `sem-router-test.el` that calls `sem-router--parse-headlines` on a temp file with at least one headline
- [x] 6.2 Verify the test proves the `cl-block` fix at runtime (not just parse time)

## 7. Add Tests for Task LLM Pipeline

- [x] 7.1 Add success path test: valid Org TODO with valid tag appended to `tasks.org`
- [x] 7.2 Add DLQ path test: malformed LLM output goes to `errors.org`, hash marked as processed
- [x] 7.3 Add retry path test: API error leaves hash NOT marked (retries next cron)
- [x] 7.4 Add tag validation test: invalid tag substituted with `:routine:`
- [x] 7.5 Add absent tag test: missing `:FILETAGS:` results in `:routine:` default

## 8. Update Existing Tests for Security Masking

- [x] 8.1 Verify existing url-capture tests still pass with new security function calls
- [x] 8.2 Add integration test for full url-capture flow with sensitive content masking

## 9. Verify and Run All Tests

- [x] 9.1 Run all existing tests to ensure no regressions
- [x] 9.2 Run all new tests to verify fixes work correctly
- [x] 9.3 Document any test failures and fix before deployment

## 10. Deployment Preparation

- [x] 10.1 Update Dockerfile if `defconst` tag list changes are needed
- [x] 10.2 Prepare deployment notes with rollback instructions
- [x] 10.3 Plan monitoring for next cron run (parse crash elimination, `errors.org` for malformed outputs)

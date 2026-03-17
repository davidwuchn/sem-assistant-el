## 1. Fix sem-router-process-inbox cl-return-from error

- [x] 1.1 Wrap `sem-router-process-inbox` body in `(cl-block sem-router-process-inbox ...)` in `sem-router.el`
- [x] 1.2 Verify the `cl-block` wraps only the try-form body, not the error handler
- [x] 1.3 Test that empty inbox no longer signals error

## 2. Implement URL capture bounded retry

- [x] 2.1 Move `sem-router--mark-processed` call from dispatch site (sem-router.el:370) into `sem-url-capture-process` callback
- [x] 2.2 Move `processed-count` increment from dispatch site into callback success branch
- [x] 2.3 Implement retry counter logic: call `sem-core--increment-retry` when `filepath` is nil
- [x] 2.4 Implement DLQ escalation: call `sem-core--mark-dlq` when retry count reaches 3
- [x] 2.5 Ensure retry counter uses headline content hash as key
- [x] 2.6 Verify headline remains unprocessed on 1st/2nd failure for retry
- [x] 2.7 Verify headline marked processed on success or DLQ

## 3. Remove dead handler functions from sem-llm.el

- [x] 3.1 Delete `sem-llm--handle-api-error` function
- [x] 3.2 Delete `sem-llm--handle-malformed-output` function
- [x] 3.3 Delete `sem-llm--handle-success` function
- [x] 3.4 Verify no production code references these functions

## 4. Fix org-roam URL sanitization

- [x] 4.1 Remove `sem-security-sanitize-urls` call from `sem-url-capture.el` (around line 352)
- [x] 4.2 Verify org-roam nodes contain valid `https://` URLs in `#+ROAM_REFS:`
- [x] 4.3 Verify `sem-security-sanitize-urls` is still called in `sem-rss.el` and `sem-router.el` task path

## 5. Fix sem-git-sync exit code handling

- [x] 5.1 Modify `sem-git-sync--run-command` to capture `call-process-shell-command` return value directly
- [x] 5.2 Remove `buffer-string` / `re-search-backward` exit code detection
- [x] 5.3 Ensure function returns `(exit-code . output-string)` with actual exit code
- [x] 5.4 Test that git failures return non-zero exit codes

## 6. Fix sem-core-purge-inbox condition-case

- [x] 6.1 Change `(t ...)` to `(error ...)` in `sem-core-purge-inbox` condition-case handler
- [x] 6.2 Verify Emacs quit signal (C-g) now propagates correctly

## 7. Remove duplicate sem-core--flush-messages

- [x] 7.1 Remove duplicate `sem-core--flush-messages` definition from `init.el` (lines 161–169)
- [x] 7.2 Verify `sem-init--install-messages-hook` still references the symbol correctly
- [x] 7.3 Verify canonical definition in `sem-core.el:168` is used

## 8. Update test suite

- [x] 8.1 Remove tests for deleted `sem-llm--handle-api-error` from `sem-retry-test.el`
- [x] 8.2 Remove tests for deleted `sem-llm--handle-malformed-output` from `sem-retry-test.el`
- [x] 8.3 Remove tests for deleted `sem-llm--handle-success` from `sem-retry-test.el`
- [x] 8.4 Add tests for URL capture bounded retry via router callback
- [x] 8.5 Add tests for `sem-git-sync--run-command` exit code detection
- [x] 8.6 Add tests verifying no URL defanging in org-roam output
- [x] 8.7 Wire all new test files into `sem-test-runner.el`
- [x] 8.8 Run full test suite: `emacs --batch --load app/elisp/tests/sem-test-runner.el` exits 0 (94 tests passed)

## 9. Verification

- [x] 9.1 Verify `sem-router-process-inbox` handles empty inbox without error
- [x] 9.2 Verify URL capture retry logic works end-to-end
- [x] 9.3 Verify org-roam nodes have valid URLs
- [x] 9.4 Verify git sync reports failures correctly
- [x] 9.5 Verify no regressions in existing tests

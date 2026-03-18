## 1. Core Module - Purge Hash Fix

- [x] 1.1 Update `sem-core-purge-inbox` hash computation to use `(concat title "|" space-joined-tags "|" body)` format
- [x] 1.2 Extract space-joined tags (without colons) from headline tags
- [x] 1.3 Extract body content from headline for hash input
- [x] 1.4 Verify hash format matches `sem-router--parse-headlines` exactly

## 2. Router Module - Security Block Destructuring Fix

- [x] 2.1 Fix destructuring of `sem-security-sanitize-for-llm` return value to use `(car result)` for sanitized-body
- [x] 2.2 Fix destructuring to use `(cdr result)` for security-blocks
- [x] 2.3 Update security block restoration to pass only `cdr` (blocks alist) to `sem-security-restore-from-llm`
- [x] 2.4 Ensure empty string body proceeds with LLM call (not skipped)

## 3. Router Module - Mutex Implementation

- [x] 3.1 Add `defvar sem-router--tasks-write-lock nil` variable definition
- [x] 3.2 Implement lock acquisition function with atomic check-and-set
- [x] 3.3 Implement lock release function using `unwind-protect`
- [x] 3.4 Add retry logic with `run-with-timer` (0.5s delay) when lock is held
- [x] 3.5 Implement retry counter tracking per callback
- [x] 3.6 Add max 10 retries check before routing to DLQ
- [x] 3.7 Integrate `sem-core-log-error` for DLQ routing after retry exhaustion
- [x] 3.8 Wrap tasks.org write in `sem-router--route-to-task-llm` with lock acquire/release

## 4. Test Updates - Core Module

- [x] 4.1 Update all `secure-hash` literals in `sem-core-test.el` to match new hash format
- [x] 4.2 Add test for hash computation with space-joined tags
- [x] 4.3 Add test for hash computation with body content
- [x] 4.4 Verify existing purge tests pass with updated hash literals

## 5. Test Updates - Router Module

- [x] 5.1 Add ERT test for correct security block round-trip (car/cdr destructuring)
- [x] 5.2 Add ERT test for mutex contention behavior (lock held, retry scheduled)
- [x] 5.3 Add ERT test for mutex lock release on error (unwind-protect)
- [x] 5.4 Add ERT test for max retry exhaustion routes to DLQ
- [x] 5.5 Add ERT test for empty body handling (proceeds with LLM call)
- [x] 5.6 Add ERT test for body-is-nil guard (no BODY section in prompt)

## 6. Verification

- [x] 6.1 Run full test suite: `emacs --batch --load app/elisp/tests/sem-test-runner.el`
- [x] 6.2 Verify all existing tests pass (except hash literal updates)
- [x] 6.3 Verify new mutex tests pass
- [x] 6.4 Verify security block tests pass
- [x] 6.5 Manual test: Simulate concurrent writes to verify lock behavior
- [x] 6.6 Manual test: Verify inbox purge removes processed items correctly

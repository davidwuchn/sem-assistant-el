## 1. Enhance sem-security.el

- [x] 1.1 Add context capturing to `sem-security--detect-sensitive-blocks` (capture up to 20 chars before/after each block)
- [x] 1.2 Update `sem-security-sanitize-for-llm` to return 3-element list: `(tokenized-text blocks-alist position-info-alist)`
- [x] 1.3 Add `sem-security-verify-tokens-present` function that returns `((missing . ()) (expanded . ()))`
- [x] 1.4 Add `sem-security--detect-sensitive-blocks-with-position` helper function

## 2. Update sem-router.el

- [x] 2.1 Update prompt in `sem-router--route-to-task-llm` with explicit token-preservation instruction
- [x] 2.2 Add BEFORE/AFTER example to prompt showing token preservation at semantic position
- [x] 2.3 Update destructuring to handle 3-element return: `(car result)`, `(cadr result)`, `(caddr result)`
- [x] 2.4 Add pre-write verification call to `sem-security-verify-tokens-present` before `sem-router--write-task-to-file`
- [x] 2.5 Handle expansion detection: reject response and log CRITICAL error if secrets found in output

## 3. Update url-capture caller (sem-url-capture.el)

- [x] 3.1 Update `sem-url-capture-process` to handle 3-element return from `sem-security-sanitize-for-llm`
- [x] 3.2 Extract `blocks-alist` (second element) for `:security-blocks` in context plist

## 4. Update unit tests

- [x] 4.1 Update `sem-security-test.el` existing tests to handle 3-element return from `sem-security-sanitize-for-llm`
- [x] 4.2 Add `sem-security-test-position-roundtrip` to verify context-preserving round-trip
- [x] 4.3 Add `sem-security-test-expansion-detection` to verify expansion detection
- [x] 4.4 Run existing unit tests to verify no regressions

## 5. Verification

- [x] 5.1 Run full unit test suite: `emacs --batch --load app/elisp/tests/sem-test-runner.el`
- [x] 5.2 Run elisplint on modified files: `sh dev/elisplint.sh app/elisp/sem-security.el app/elisp/sem-router.el`

## 6. Integration Testing (requires human operator)

- [x] 6.1 Human operator runs integration tests: `bash dev/integration/run-integration-tests.sh`
- [x] 6.2 Verify Assertion 4 (Sensitive content restoration) passes: `grep "ASSERTION_4_RESULT:PASS" test-results/*/assertion-results.txt`
- [x] 6.3 If integration tests fail, report results to agent for investigation

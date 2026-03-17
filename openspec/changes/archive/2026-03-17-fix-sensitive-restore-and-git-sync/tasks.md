## 1. Fix Sensitive Content Restoration in URL Capture

- [x] 1.1 Locate the LLM callback in `sem-url-capture-process` where `response` is checked for nil
- [x] 1.2 Add call to `(sem-security-restore-from-llm response (plist-get context :security-blocks))` after nil-check and before `sem-url-capture--validate-and-save`
- [x] 1.3 Pass the restored result to `sem-url-capture--validate-and-save` instead of raw response
- [x] 1.4 Verify the change compiles without errors

## 2. Fix Git Sync Module Loading

- [x] 2.1 Open `init.el` and locate `sem-init--load-modules` function
- [x] 2.2 Find the line `(require 'sem-url-capture)`
- [x] 2.3 Add `(require 'sem-git-sync)` immediately after `(require 'sem-url-capture)` and before `(require 'sem-router)`
- [x] 2.4 Verify the change compiles without errors

## 3. Update Security-Masking Spec

- [x] 3.1 Open `openspec/specs/security-masking/spec.md`
- [x] 3.2 Locate the "Requirement: Tokens restored in output before writing" section
- [x] 3.3 Update the requirement text to state `sem-security-restore-from-llm` SHALL be called in `sem-url-capture-process`
- [x] 3.4 Remove or update the scenario "restore-from-llm NOT called in url-capture"
- [x] 3.5 Add scenario "restore-from-llm called before validate-and-save in url-capture"

## 4. Add Unit Test for sem-security-restore-from-llm

- [x] 4.1 Open or create `app/elisp/tests/sem-url-capture-test.el`
- [x] 4.2 Add ERT test `sem-url-capture-test-restore-from-llm-unit`
- [x] 4.3 Test verifies: given `<<SENSITIVE_1>>` token and corresponding `security-blocks` alist, function returns string with `SECRET` and no `<<SENSITIVE_1>>`
- [x] 4.4 Run test and verify it passes

## 5. Add Integration Test for URL Capture Restore Pipeline

- [x] 5.1 In `app/elisp/tests/sem-url-capture-test.el`, add ERT test `sem-url-capture-test-restore-integration`
- [x] 5.2 Stub `sem-llm-request` to return response containing `<<SENSITIVE_1>>`
- [x] 5.3 Run `sem-url-capture-process` with pre-populated `:security-blocks` in context
- [x] 5.4 Assert saved file contains restored sensitive block text, not the token
- [x] 5.5 Run test and verify it passes

## 6. Add Module Load Test for sem-git-sync

- [x] 6.1 Open or create `app/elisp/tests/sem-init-test.el`
- [x] 6.2 Add ERT test `sem-init-test-git-sync-loaded`
- [x] 6.3 Mock all `require` calls to no-ops and call `sem-init--load-modules`
- [x] 6.4 Assert `sem-git-sync` is in the list of required modules
- [x] 6.5 Assert `fboundp 'sem-git-sync-org-roam` returns `t` after load
- [x] 6.6 Run test and verify it passes

## 7. Verify All Existing Tests Pass

- [x] 7.1 Run full ERT test suite
- [x] 7.2 Verify no regressions in existing tests (118 tests passed)
- [x] 7.3 Fix any failing tests if needed (none needed)

## 8. Final Verification

- [x] 8.1 Manual test: verify sensitive blocks are restored in url-capture workflow (verified via integration test)
- [x] 8.2 Manual test: verify `sem-git-sync-org-roam` is bound after init (verified via module load test)
- [x] 8.3 Review all changes for code quality (changes are minimal and focused)

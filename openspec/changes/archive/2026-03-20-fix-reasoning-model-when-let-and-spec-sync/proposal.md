## Why

The codebase has accumulated issues requiring fixes before production readiness:
1. Reasoning models (qwen3.5, etc.) cause noisy error logs due to thinking trace inclusion in LLM responses
2. `when-let` obsolete macro (Emacs 31.1 deprecation) causes compiler warnings
3. Multiple spec/code mismatches create confusion and potential for bugs
4. Integration tests lack coverage for sensitive block handling and cron verification

## What Changes

### Code Fixes

1. **init.el**: Add `:request-params '(:reasoning (:exclude t))` to gptel backend to suppress thinking trace from reasoning models
2. **sem-rss.el**: Replace `when-let` with `when-let*` at lines 21 and 27 to fix deprecation warnings
3. **sem-llm.el**: Add comprehensive logging to sem-llm-request:
   - Log prompt length on call (token estimate = length/4)
   - Log response length and token count on success
   - Log all errors via sem-core-log-error with input recorded
4. **sem-security.el**: Update comment at line 85 to remove incorrect org-roam exclusion statement (code behavior is correct, comment was wrong)

### Spec Syncs

4. **security-masking/spec.md**: Update token format from `{{SEC_ID_xxx}}` to `<<SENSITIVE_xxx>>` to match code
5. **security-masking/spec.md** & **url-capture/spec.md**: Clarify that URL sanitization is NOT applied to url-capture output (org-roam requires real URLs for link resolution)
6. **test-inbox-resource/spec.md**: Update tag format from `@task` to `:task:` (Org tag syntax uses colons)
7. **README.md**: Update tag format from `:@task:` to `:task:` to match actual code
8. **inbox-upload/spec.md**: Add documentation that WebDAV URL path uses `/data/` prefix (e.g., `${WEBDAV_BASE_URL}/data/inbox-mobile.org`)

### Integration Test Extensions

9. **inbox-tasks.org**: Add headline with `#+begin_sensitive`/`#+end_sensitive` block to test sensitive content restoration
10. **run-integration-tests.sh**: Add validation that sensitive content is correctly restored in tasks.org output
11. **run-integration-tests.sh**: Add cron/emacsclient verification test to confirm scheduled commands execute correctly

## Capabilities

### Modified Capabilities

- **sem-llm**: Add reasoning exclusion to suppress thinking traces; add comprehensive logging with token counts on success and errors
- **sem-rss**: Replace obsolete `when-let` with `when-let*`
- **test-inbox-resource**: Update tag format documentation; add sensitive block test case
- **security-masking**: Sync token format to code; clarify URL sanitization scope
- **url-capture**: Clarify URL sanitization not applied to org-roam output
- **inbox-upload**: Document correct WebDAV URL path with `/data/` prefix
- **README.md**: Sync task tag format to `:task:`

### New Capabilities

- **cron-verification-test**: Integration test to verify emacsclient execution and cron job functionality

## Impact

- Reasoning models will produce clean logs without thinking trace noise
- Emacs 31.1 deprecation warnings eliminated
- Specs accurately reflect code behavior, reducing confusion
- Integration test coverage improved for sensitive content and cron

## Execution Workflow

### Phase 1: Unit Tests Pass (Agent runs)

All 12 existing unit test files must pass after changes. No regression allowed.

**Current test files (must all pass):**
1. `app/elisp/tests/sem-core-test.el` - cursor and logging functions
2. `app/elisp/tests/sem-security-test.el` - security masking
3. `app/elisp/tests/sem-prompts-test.el` - prompt constants
4. `app/elisp/tests/sem-router-test.el` - inbox routing
5. `app/elisp/tests/sem-rss-test.el` - RSS functions (may need update for when-let fix verification)
6. `app/elisp/tests/sem-url-capture-test.el` - URL capture
7. `app/elisp/tests/sem-llm-test.el` - LLM request handling (may need update for new logging)
8. `app/elisp/tests/sem-async-test.el` - async behavior (may need update for sem-llm-request logging)
9. `app/elisp/tests/sem-retry-test.el` - retry mechanism
10. `app/elisp/tests/sem-git-sync-test.el` - git sync
11. `app/elisp/tests/sem-url-sanitize-test.el` - URL sanitization
12. `app/elisp/tests/sem-init-test.el` - module initialization

**Run command:**
```sh
emacs --batch --load app/elisp/tests/sem-test-runner.el
```

**Tests requiring verification after changes:**
- `sem-rss-test.el`: Verify `when-let*` change doesn't break defconst initializers
- `sem-llm-test.el`: May need mock updates if logging changes callback behavior
- `sem-async-test.el`: Verify sem-llm-request logging doesn't break async tests

### Phase 2: Update Integration Tests (Agent)

Update integration test resources and scripts:
- Add sensitive block test case to `inbox-tasks.org`
- Add sensitive content restoration validation to `run-integration-tests.sh`
- Add cron/emacsclient verification function to `run-integration-tests.sh`
- Do NOT run integration tests (human-only)

### Phase 3: Human Verification (Human runs)

Human operator runs integration tests and provides feedback:
```sh
bash dev/integration/run-integration-tests.sh
```

Human reports results to agent for feedback loop.

### Phase 4: Remaining Tasks (Agent)

After human feedback on integration tests, address any remaining issues.

## Non-Goals

- GitHub sync improvements (out of scope)
- URL sanitization for org-roam output (intentionally excluded)
- Changes to actual task processing logic (only spec/code sync)
- Integration test execution by agent (human-only)

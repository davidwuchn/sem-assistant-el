## 1. Code Fixes

- [x] 1.1 init.el: Add `:request-params '(:reasoning (:exclude t))` to gptel backend in `sem-init--configure-gptel`
- [x] 1.2 sem-rss.el: Replace `when-let` with `when-let*` at line 21 (`sem-rss-max-entries-per-feed`)
- [x] 1.3 sem-rss.el: Replace `when-let` with `when-let*` at line 27 (`sem-rss-max-input-chars`)
- [x] 1.4 sem-llm.el: Add prompt length logging on `sem-llm-request` call (token estimate = length/4)
- [x] 1.5 sem-llm.el: Add response length and token count logging on success
- [x] 1.6 sem-llm.el: Add error logging with input recorded via `sem-core-log-error`
- [x] 1.7 sem-security.el: Update comment at line 85 to remove incorrect org-roam exclusion statement (SKIPPED - comment was already correct)

## 2. Spec Syncs

- [x] 2.1 security-masking/spec.md: Update token format from `{{SEC_ID_xxx}}` to `<<SENSITIVE_xxx>>` in scenarios
- [x] 2.2 security-masking/spec.md: Add REMOVED section for URL sanitization requirement
- [x] 2.3 url-capture/spec.md: Add requirement that URL sanitization is NOT applied to org-roam output
- [x] 2.4 test-inbox-resource/spec.md: Update tag format from `@task` to `:task:` in all scenarios
- [x] 2.5 README.md: Update tag format from `:@task:` to `:task:`
- [x] 2.6 inbox-upload/spec.md: Document WebDAV URL path uses `/data/` prefix (e.g., `${WEBDAV_BASE_URL}/data/inbox-mobile.org`)

## 3. Integration Test Extensions

- [x] 3.1 inbox-tasks.org: Add headline with `#+begin_sensitive`/`#+end_sensitive` block for sensitive content test
- [x] 3.2 run-integration-tests.sh: Add validation that sensitive content is correctly restored in tasks.org output
- [x] 3.3 run-integration-tests.sh: Add cron/emacsclient verification test function

## 4. Verification

- [x] 4.1 Run elisplint.sh on modified elisp files to check for parenthesis errors
- [x] 4.2 Run unit test suite: `emacs --batch --load app/elisp/tests/sem-test-runner.el`
- [x] 4.3 Verify sem-rss-test.el passes with `when-let*` change
- [x] 4.4 Verify sem-llm-test.el passes with new logging
- [x] 4.5 Verify sem-async-test.el passes with sem-llm-request logging changes

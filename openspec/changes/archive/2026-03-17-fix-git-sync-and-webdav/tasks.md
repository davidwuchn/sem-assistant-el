## 1. Fix sem-git-sync--setup-ssh

- [x] 1.1 Wrap function body in `(cl-block sem-git-sync--setup-ssh ...)` inside `condition-case`
- [x] 1.2 Replace `eval $(ssh-agent -s)` shell command with direct `ssh-agent -s` execution
- [x] 1.3 Parse SSH_AUTH_SOCK from output using regex `SSH_AUTH_SOCK=\\([^;]+\\)`
- [x] 1.4 Parse SSH_AGENT_PID from output using regex `SSH_AGENT_PID=\\([0-9]+\\)`
- [x] 1.5 Call `(setenv "SSH_AUTH_SOCK" <value>)` and `(setenv "SSH_AGENT_PID" <value>)` in Emacs process
- [x] 1.6 Handle parsing failure: log FAIL and return nil if either regex fails to match
- [x] 1.7 Handle ssh-agent failure: log FAIL and return nil if command returns non-zero exit

## 2. Fix sem-git-sync-org-roam

- [x] 2.1 Wrap function body in `(cl-block sem-git-sync-org-roam ...)` inside `condition-case`
- [x] 2.2 Ensure `condition-case` remains outermost wrapper with `cl-block` as direct child
- [x] 2.3 Verify all existing `cl-return-from` call sites work without signaling errors

## 3. Fix straight.el lockfile

- [x] 3.1 Replace contents of `app/elisp/straight/versions/default.el` with valid lockfile format
- [x] 3.2 Add `(straight-use-package 'gptel :pin "<40-char-SHA>")` with correct SHA
- [x] 3.3 Add `(straight-use-package 'elfeed :pin "<40-char-SHA>")` with correct SHA
- [x] 3.4 Add `(straight-use-package 'elfeed-org :pin "<40-char-SHA>")` with correct SHA
- [x] 3.5 Add `(straight-use-package 'org-roam :pin "<40-char-SHA>")` with correct SHA
- [x] 3.6 Add `(straight-use-package 'websocket :pin "<40-char-SHA>")` with correct SHA
- [x] 3.7 Ensure file begins with standard Elisp header
- [x] 3.8 Ensure file ends with `(provide 'default)`
- [x] 3.9 Remove all references to non-existent `straight-versions` function
- [x] 3.10 Verify `bootstrap-packages.el` calls `(straight-thaw-versions)` after bootstrap and before package installation

## 4. Fix WebDAV TLS configuration

- [x] 4.1 Update `webdav-config.yml` cert path to `/certs/live/{env}WEBDAV_DOMAIN/fullchain.pem`
- [x] 4.2 Update `webdav-config.yml` key path to `/certs/live/{env}WEBDAV_DOMAIN/privkey.pem`
- [x] 4.3 Add `WEBDAV_DOMAIN` to `.env.example` with documentation comment
- [x] 4.4 Verify `docker-compose.yml` webdav mount remains `/etc/letsencrypt:/certs:ro`

## 5. Add unit tests for git sync fixes

- [x] 5.1 Add `sem-git-sync-test-setup-ssh-parses-auth-sock` test with mocks for SSH agent output parsing
- [x] 5.2 Add `sem-git-sync-test-setup-ssh-returns-nil-on-missing-sock` test for malformed output handling
- [x] 5.3 Add `sem-git-sync-test-setup-ssh-returns-nil-on-agent-failure` test for command failure handling
- [x] 5.4 Add `sem-git-sync-test-org-roam-returns-nil-on-missing-dir` test for early exit on missing directory
- [x] 5.5 Add `sem-git-sync-test-org-roam-returns-t-on-no-changes` test for successful no-op scenario
- [x] 5.6 Add `sem-git-sync-test-org-roam-cl-return-from-no-signal` regression test for cl-return-from bug
- [x] 5.7 Run full test suite: `emacs --batch --load app/elisp/tests/sem-test-runner.el` exits with code 0
- [x] 5.8 Verify all 94 pre-existing tests still pass
- [x] 5.9 Verify total test count is at least 100 (94 existing + 6 new)

## 6. Verification and documentation

- [x] 6.1 Review all changes against design.md decisions
- [x] 6.2 Verify no changes to out-of-scope files (sem-core.el, sem-router.el, etc.)
- [x] 6.3 Confirm bootstrap-packages.el modification (if needed for straight-thaw-versions)
- [x] 6.4 Run ERT tests to validate implementation

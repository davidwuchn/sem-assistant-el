## Why

Three runtime bugs prevent `sem-git-sync-org-roam` from ever succeeding:

1. `cl-return-from` is called in `sem-git-sync--setup-ssh` and `sem-git-sync-org-roam` without a matching `cl-block` wrapper. Every early-exit path signals a Lisp error caught by the outer `condition-case`, which logs FAIL and returns nil — making no early-exit path reachable as intended.
2. `sem-git-sync--setup-ssh` starts `ssh-agent` via `call-process-shell-command "eval $(ssh-agent -s)"`. The subprocess exits; `SSH_AUTH_SOCK` and `SSH_AGENT_PID` are never set in the Emacs process environment. The subsequent `ssh-add` call runs without an agent and fails silently. Git push over SSH never authenticates.
3. `straight/versions/default.el` uses the non-existent function `straight-versions` instead of the real straight.el lockfile API (`straight-use-package` with `:pin`). The file is silently ignored at build time. Packages are fetched from the HEAD of their default branch on every `docker-compose build`, making builds non-reproducible.

Additionally, `webdav-config.yml` specifies `cert.pem`/`key.pem` but Let's Encrypt generates `fullchain.pem`/`privkey.pem`. The WebDAV container fails TLS startup on a standard Let's Encrypt installation.

## What Changes

- `app/elisp/sem-git-sync.el`: fix `cl-return-from` usage; fix SSH agent setup.
- `app/elisp/straight/versions/default.el`: replace stub with a valid straight.el lockfile.
- `webdav-config.yml`: correct TLS certificate filenames.

## Capabilities

### Modified Capabilities

- `sem-git-sync--setup-ssh`: Wrap the entire `defun` body in `(cl-block sem-git-sync--setup-ssh ...)` immediately inside `condition-case`. All existing `(cl-return-from sem-git-sync--setup-ssh ...)` call sites remain unchanged. Additionally: replace `(sem-git-sync--run-command "eval $(ssh-agent -s)")` with a direct call to `ssh-agent -s` (no `eval`); parse its stdout to extract `SSH_AUTH_SOCK=<value>` and `SSH_AGENT_PID=<value>` using `string-match`; call `(setenv "SSH_AUTH_SOCK" <value>)` and `(setenv "SSH_AGENT_PID" <value>)` in the Emacs process before proceeding to `ssh-add`. If parsing fails (no match), log FAIL and `cl-return-from` with nil. The SSH_AUTH_SOCK and SSH_AGENT_PID values must be extracted from the line `SSH_AUTH_SOCK=<path>; export SSH_AUTH_SOCK;` and `SSH_AGENT_PID=<pid>; export SSH_AGENT_PID;` respectively, which is the exact output format of `ssh-agent -s`. The regex for SSH_AUTH_SOCK: `"SSH_AUTH_SOCK=\\([^;]+\\)"`. The regex for SSH_AGENT_PID: `"SSH_AGENT_PID=\\([0-9]+\\)"`. Both must match; if either is absent, log FAIL and return nil.

- `sem-git-sync-org-roam`: Wrap the entire `defun` body (the content currently inside `condition-case`) in `(cl-block sem-git-sync-org-roam ...)`. The `condition-case` must remain as the outermost wrapper; `cl-block` must be the direct child of `condition-case`'s body. All existing `(cl-return-from sem-git-sync-org-roam ...)` call sites remain unchanged. No other logic changes.

- `straight-lockfile`: Replace `app/elisp/straight/versions/default.el` with a valid straight.el lockfile. The correct format is one `(straight-use-package '<pkg> :pin "<40-char-SHA>")` call per package. Packages to pin: `gptel`, `elfeed`, `elfeed-org`, `org-roam`, `websocket`. SHAs must be obtained by running `git -C ~/.emacs.d/straight/repos/<pkg> rev-parse HEAD` inside the Docker build container after packages are installed, or retrieved from the current state of the container's straight repos directory. The file must begin with the standard Elisp header and end with `(provide 'default)`. The `straight-versions` function does not exist and must be completely removed.

- `webdav-tls-config`: In `webdav-config.yml`, change `cert: /certs/cert.pem` to `cert: /certs/live/<domain>/fullchain.pem` and `key: /certs/key.pem` to `key: /certs/live/<domain>/privkey.pem`. The `<domain>` placeholder must be replaced with a shell-expandable environment variable reference so that the actual domain is configurable without editing the file: use `{env}WEBDAV_DOMAIN`. The `docker-compose.yml` mount for the webdav service must remain `/etc/letsencrypt:/certs:ro` — do not change it. Add `WEBDAV_DOMAIN` to `.env.example` with a comment explaining it must match the Let's Encrypt certificate domain.

## Impact

- `sem-git-sync.el` changes affect only the git sync cron job (runs every 6 hours). No other modules import or call `sem-git-sync-org-roam` or `sem-git-sync--setup-ssh`.
- Lockfile fix affects Docker build reproducibility only. Runtime behavior is unchanged if all packages are already installed at the pinned versions.
- `webdav-config.yml` change affects the WebDAV container TLS startup. Requires the host to have `/etc/letsencrypt/live/<domain>/` populated by certbot. Deployments without Let's Encrypt must set `tls: false` and remove the cert/key lines — this is an existing out-of-scope operator concern.
- `bootstrap-packages.el` is **not** modified. It does not reference the lockfile; the lockfile is loaded separately by straight.el via `straight-thaw-versions`. Confirm that `bootstrap-packages.el` or `init.el` calls `straight-thaw-versions` to activate the lockfile; if it does not, add a single `(straight-thaw-versions)` call to `bootstrap-packages.el` after the bootstrap block and before the `straight-use-package` calls. Do not add it to `init.el`.
- No changes to `sem-core.el`, `sem-router.el`, `sem-url-capture.el`, `sem-rss.el`, `sem-llm.el`, `sem-security.el`, `init.el`, `Dockerfile.emacs`, `docker-compose.yml`.
- Out of scope: LLM rate limiting, SSH key rotation, git rebase/pull before push, cron environment injection of SSH vars, `Dockerfile.webdav` removal, package lockfile automation.

## Testing Requirements

### Test file

All new tests for `sem-git-sync.el` changes MUST be added to the **existing** file `app/elisp/tests/sem-git-sync-test.el`. Do not create new test files.

### Test runner wiring

`app/elisp/tests/sem-test-runner.el` already contains the line:
```elisp
(load-file (expand-file-name "sem-git-sync-test.el" (file-name-directory load-file-name)))
```
Do not add any new `load-file` lines to `sem-test-runner.el`. The new tests are automatically picked up because they live in `sem-git-sync-test.el` which is already loaded.

### Required new tests

Add the following ERT tests to `sem-git-sync-test.el`. Each test name must begin with `sem-git-sync-test-`. All tests must be pure unit tests using mocks — no SSH binary, no real git repo, no filesystem writes outside of `temporary-file-directory`.

1. **`sem-git-sync-test-setup-ssh-parses-auth-sock`**: Mock `sem-git-sync--run-command` to return `(0 . "SSH_AUTH_SOCK=/tmp/ssh-abc/agent.123; export SSH_AUTH_SOCK;\nSSH_AGENT_PID=456; export SSH_AGENT_PID;\n")` for the `ssh-agent -s` call. Assert that after `sem-git-sync--setup-ssh` runs, `(getenv "SSH_AUTH_SOCK")` equals `"/tmp/ssh-abc/agent.123"` and `(getenv "SSH_AGENT_PID")` equals `"456"`. Restore original env vars in `:teardown`. Mock `file-exists-p` for `sem-git-sync-ssh-key` to return `t`. Mock the `ssh-add` call to return `(0 . "")`.

2. **`sem-git-sync-test-setup-ssh-returns-nil-on-missing-sock`**: Mock `sem-git-sync--run-command` for `ssh-agent -s` to return `(0 . "malformed output without expected vars")`. Assert that `sem-git-sync--setup-ssh` returns `nil`. Assert no Lisp error is signaled (the function must not escape via `cl-return-from` without `cl-block`, which would previously throw).

3. **`sem-git-sync-test-setup-ssh-returns-nil-on-agent-failure`**: Mock `sem-git-sync--run-command` for `ssh-agent -s` to return `(1 . "")`. Assert `sem-git-sync--setup-ssh` returns `nil`.

4. **`sem-git-sync-test-org-roam-returns-nil-on-missing-dir`**: Mock `file-directory-p` to return `nil`. Assert `sem-git-sync-org-roam` returns `nil`. Assert no Lisp error is signaled.

5. **`sem-git-sync-test-org-roam-returns-t-on-no-changes`**: Mock `file-directory-p` → `t`. Mock `sem-git-sync--run-command "git rev-parse --git-dir"` → `(0 . ".git\n")`. Mock `sem-git-sync--has-changes-p` → `nil`. Assert `sem-git-sync-org-roam` returns `t` (no-changes is a successful no-op). Assert no Lisp error is signaled.

6. **`sem-git-sync-test-org-roam-cl-return-from-no-signal`**: This is the regression test for the `cl-return-from` bug. Call `sem-git-sync-org-roam` with `file-directory-p` mocked to return `nil`. The test passes if the call returns `nil` without signaling `(error "Return from unknown block")`. Use `condition-case` in the test body to catch any error and `should-not` to assert no error was signaled.

### Mock pattern

Use the same `cl-letf` / `advice-add` pattern already established in `sem-mock.el` and the existing `sem-git-sync-test.el` tests. Do not introduce new mocking libraries.

### Regression requirement

Running `emacs --batch --load app/elisp/tests/sem-test-runner.el` must exit with code 0. All 94 pre-existing tests must continue to pass. The total test count after this change must be at least 100 (94 existing + 6 new minimum).

## Context

The `sem-git-sync-org-roam` function is responsible for automatically syncing the org-roam notes directory to a remote git repository every 6 hours via cron. Currently, this functionality is completely broken due to three runtime bugs:

1. **cl-return-from without cl-block**: The `cl-return-from` macro requires a matching `cl-block` wrapper to define the block name. Without it, calling `cl-return-from` signals a Lisp error that gets caught by the outer `condition-case`, logging FAIL and returning nil. This makes no early-exit path reachable as intended.

2. **SSH agent environment not captured**: The current implementation uses `eval $(ssh-agent -s)` via shell command, but subprocess environment variables are never propagated back to the Emacs process. This means `SSH_AUTH_SOCK` and `SSH_AGENT_PID` are never set, causing subsequent `ssh-add` and git push operations to fail.

3. **Invalid straight.el lockfile**: The `straight/versions/default.el` file uses a non-existent `straight-versions` function instead of the proper `straight-use-package` with `:pin` syntax. This makes Docker builds non-reproducible as packages are always fetched from HEAD.

4. **WebDAV TLS certificate path mismatch**: The `webdav-config.yml` references `cert.pem`/`key.pem` but Let's Encrypt generates `fullchain.pem`/`privkey.pem`, causing TLS startup failures.

## Goals / Non-Goals

**Goals:**
- Fix `cl-return-from` usage by wrapping function bodies in `cl-block`
- Fix SSH agent setup by parsing `ssh-agent -s` output and setting environment variables directly
- Replace invalid lockfile with proper straight.el pin format
- Correct WebDAV TLS certificate paths to match Let's Encrypt conventions
- Add `WEBDAV_DOMAIN` environment variable support for configurable domains
- Ensure all changes are testable with unit tests using mocks

**Non-Goals:**
- Changing the cron schedule or git sync frequency
- Adding SSH key rotation functionality
- Implementing git rebase/pull before push
- Automating lockfile generation from package updates
- Modifying Dockerfile.webdav or removing it
- Adding LLM rate limiting
- Supporting non-Let's Encrypt certificate layouts (operators must set `tls: false`)

## Decisions

### 1. cl-block Placement

**Decision:** Wrap the entire function body (inside `condition-case`) with `cl-block`.

**Rationale:** The `condition-case` must remain the outermost wrapper to catch all errors including those from `cl-return-from`. The `cl-block` is placed as the direct child of `condition-case`'s body form. This maintains the existing error handling behavior while enabling proper early-exit semantics.

**Alternative considered:** Wrapping only specific sections in `cl-block`. Rejected because `cl-return-from` calls exist at multiple points throughout the function and all need the same block context.

### 2. SSH Agent Output Parsing

**Decision:** Parse `ssh-agent -s` stdout directly using `string-match` with regex patterns `"SSH_AUTH_SOCK=\\([^;]+\\)"` and `"SSH_AGENT_PID=\\([0-9]+\\)"`.

**Rationale:** This avoids shell evaluation entirely and gives Emacs direct control over environment variable setting via `setenv`. The output format is stable across OpenSSH versions.

**Alternative considered:** Using `exec-path-from-shell` or similar packages. Rejected to avoid adding new dependencies for a simple parsing task.

### 3. Lockfile Format

**Decision:** Use `(straight-use-package '<pkg> :pin "<sha>")` format with explicit package list.

**Rationale:** This is the documented straight.el lockfile API. The packages to pin (`gptel`, `elfeed`, `elfeed-org`, `org-roam`, `websocket`) are the core dependencies that affect runtime behavior.

**Alternative considered:** Using `straight-freeze-versions` programmatically. Rejected because we need a static file that can be version-controlled and reviewed.

### 4. WebDAV Domain Configuration

**Decision:** Use `{env}WEBDAV_DOMAIN` syntax in `webdav-config.yml` and add `WEBDAV_DOMAIN` to `.env.example`.

**Rationale:** This allows the same `docker-compose.yml` and `webdav-config.yml` to work across different deployments without file modification. The `{env}` syntax is commonly supported by WebDAV server configurations.

**Alternative considered:** Hardcoding domain or using a config template. Rejected in favor of direct environment variable substitution for simplicity.

### 5. Test Strategy

**Decision:** Add 6 new ERT tests to the existing `sem-git-sync-test.el` using `cl-letf` mocking pattern.

**Rationale:** The existing test infrastructure already supports mocking via `cl-letf` and `advice-add`. Pure unit tests with mocks avoid requiring actual SSH keys, git repositories, or network access in CI.

**Alternative considered:** Integration tests with real SSH keys. Rejected because they would require complex CI setup and be flaky.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| SSH agent output format changes in future OpenSSH versions | The format has been stable for decades; if it changes, the regex will fail to match and the function will return nil (safe failure) |
| `cl-block`/`cl-return-from` behavior differences across Emacs versions | `cl-lib` is part of Emacs core and behavior is stable; tests will catch any regressions |
| Lockfile SHAs become stale if packages update | This is intentional - reproducible builds require explicit SHA updates; operators can update SHAs when needed |
| `WEBDAV_DOMAIN` not set causes WebDAV startup failure | Documented in `.env.example`; operator must set it or disable TLS |
| Mock-based tests don't catch real SSH/git integration issues | Integration issues are out of scope; the cron job logs provide visibility into real failures |

## Migration Plan

1. **Deploy changes:**
   - Update `app/elisp/sem-git-sync.el` with `cl-block` wrappers and SSH parsing
   - Replace `app/elisp/straight/versions/default.el` with valid lockfile
   - Update `webdav-config.yml` with correct cert paths and `{env}WEBDAV_DOMAIN`
   - Add `WEBDAV_DOMAIN` to `.env.example`

2. **Activate lockfile:**
   - Verify `bootstrap-packages.el` calls `straight-thaw-versions` after bootstrap
   - If missing, add the call before `straight-use-package` calls

3. **Configure environment:**
   - Set `WEBDAV_DOMAIN` in `.env` to match Let's Encrypt certificate domain
   - Ensure `/etc/letsencrypt/live/$WEBDAV_DOMAIN/` exists with `fullchain.pem` and `privkey.pem`

4. **Rollback strategy:**
   - All changes are file replacements; revert to previous git commit to rollback
   - No database migrations or stateful changes involved

## Open Questions

None - all technical decisions are resolved in this design.

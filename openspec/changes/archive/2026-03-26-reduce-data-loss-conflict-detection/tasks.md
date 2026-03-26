## 1. Conflict-aware planner concurrency

- [x] 1.1 Add base hash capture for `tasks.org` before Pass 2 context generation.
- [x] 1.2 Add pre-append hash recheck and block append when the current hash differs from the base hash.
- [x] 1.3 Rebuild Pass 2 input from freshly read `tasks.org` after hash mismatch and rerun planning.

## 2. Retry and conflict outcome handling

- [x] 2.1 Add bounded retry loop for conflict-driven replanning with deterministic attempt counting.
- [x] 2.2 Return explicit non-success outcome when retry budget is exhausted, with no stale append fallback.
- [x] 2.3 Emit deterministic conflict logs for detect/retry/success-or-fail paths using existing module/status conventions.

## 3. Production WebDAV runtime migration

- [x] 3.1 Replace production `webdav` service runtime from `hacdias/webdav` to Apache `httpd` + `mod_dav`.
- [x] 3.2 Configure conditional write enforcement so stale client writes are rejected via HTTP precondition failure.
- [x] 3.3 Ensure write-conflict behavior requires pull-before-push recovery for clients after rejection.
- [x] 3.4 Enforce strict precondition policy for write requests with missing or weak conditional headers (reject, never downgrade to unconditional overwrite).

## 4. Preserve TLS and Certbot contracts

- [x] 4.1 Keep `WEBDAV_DOMAIN`-driven cert resolution using `/certs/live/<domain>/fullchain.pem` and `privkey.pem`.
- [x] 4.2 Preserve `/etc/letsencrypt:/certs:ro,z` compose mount and fail startup when required auth/cert config is missing.
- [x] 4.3 Verify Certbot renewal/restart flow remains compatible with Apache WebDAV without certificate path changes.

## 5. Keep integration test runtime stable

- [x] 5.1 Update `dev/integration/docker-compose.test.yml` only as needed to remain deterministic and non-TLS.
- [x] 5.2 Keep `dev/integration/webdav-config.test.yml` independent of production Apache TLS and conditional-write settings.
- [x] 5.3 Ensure integration runner assumptions (container naming, lifecycle, artifact paths) remain unchanged.

## 6. Verification and regression coverage

- [x] 6.1 Add or update unit tests for hash mismatch rejection, replan retry flow, and retry exhaustion non-success behavior.
- [x] 6.2 Add or update tests/fixtures for WebDAV stale-write rejection and fresh-write success semantics.
- [x] 6.3 Add or update tests/fixtures that verify missing or weak conditional headers are rejected and no unconditional-write fallback path exists.
- [x] 6.4 Run repository test suite and targeted compose/config checks, then document migration and rollback notes.

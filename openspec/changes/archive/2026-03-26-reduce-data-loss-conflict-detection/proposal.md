## Why

Concurrent writes from Pass 2 planning and mobile WebDAV sync can still produce silent last-writer-wins overwrites in `tasks.org`. Atomic rename prevents partial files but does not prevent stale-read overwrite. We need explicit conflict detection in both the daemon planning path and the WebDAV write path so stale writers fail fast instead of silently discarding newer content.

## What Changes

- Add daemon-side optimistic concurrency for Pass 2: compute `tasks.org` content hash before Pass 2 input generation, re-check the hash immediately before final append, and if changed, rebuild Pass 2 context from fresh file state and rerun planning under bounded retry.
- Add WebDAV-side write precondition enforcement by migrating production WebDAV service from `hacdias/webdav` to Apache `httpd` + `mod_dav` with conditional-write rejection semantics so stale client uploads are rejected and require pull-before-push behavior.
- Preserve current production TLS contract and operations: Certbot HTTP-01 flow, `/etc/letsencrypt:/certs:ro,z` mount, `WEBDAV_DOMAIN`-driven certificate paths, and existing restart/renewal operational model.
- Preserve integration-test invariants: test WebDAV remains non-TLS and independent of Certbot/host certificates, test compose override behavior remains deterministic, and integration assertions continue to run without new paid external dependencies.
- Add explicit failure handling constraints: no silent fallback that bypasses conflict detection, no destructive overwrite on mismatch, bounded retries for daemon replan loops, and deterministic logging for conflict outcomes.
- Require explicit updates to existing OpenSpec capabilities in this change scope: `two-pass-scheduling`, `atomic-tasks-org-update`, `inbox-processing`, `webdav-sync`, `webdav-tls`, `webdav-tls-config`, `certbot-http01-webdav-tls`, `test-compose-override`, and `test-webdav-config`.

## Capabilities

### New Capabilities

- `tasks-org-conflict-aware-planning`: Pass 2 planning uses optimistic concurrency against `tasks.org` with strict pre-append hash verification, mandatory replan on mismatch, bounded retry to prevent livelock, and explicit non-success outcome when contention does not stabilize.
- `webdav-conditional-write-rejection`: Production WebDAV write path rejects stale writes using conditional request semantics so conflicting client pushes fail explicitly instead of silently overwriting newer server state.

### Modified Capabilities

- `two-pass-scheduling`: Pass 2 now includes file-version validation between planning-read and append-write phases; merge success requires unchanged base version or successful replan against latest version.
- `atomic-tasks-org-update`: Atomic append semantics are extended with base-version verification and conflict retry/abort behavior; re-read alone is no longer considered sufficient for conflict safety.
- `inbox-processing`: Documented sync-risk behavior is updated to reflect conflict-aware planner append outcomes (retry/reject paths) instead of silent overwrite assumptions during planner merge windows.
- `webdav-sync`: Bidirectional sync behavior is updated to require explicit stale-write rejection outcomes for conflicting client pushes.
- `webdav-tls`: Production WebDAV runtime is no longer tied to `hacdias/webdav`; capability is updated for Apache `httpd` + `mod_dav` while preserving HTTPS service behavior.
- `webdav-tls-config`: WebDAV backend implementation changes to Apache while preserving TLS certificate source, domain-driven cert path behavior, and operator-facing TLS compatibility with existing Certbot outputs.
- `certbot-http01-webdav-tls`: Certbot issuance/renewal behavior remains primary and unchanged in scope, but must remain compatible with the new WebDAV runtime container and mount topology.
- `test-compose-override`: Integration override must continue to exclude production TLS/Certbot dependencies and keep non-TLS test WebDAV startup deterministic.
- `test-webdav-config`: Test WebDAV config remains non-TLS and must not inherit Apache production-only conditional-write/TLS requirements.
- `integration-test-runner`: Existing integration execution and assertions remain valid; any WebDAV service substitution must not break artifact collection paths, container naming assumptions, or test lifecycle orchestration.

## Impact

- Data-loss risk is reduced by converting silent overwrite classes into explicit conflict outcomes at both daemon and sync boundaries.
- Runtime behavior changes under contention: some writes will be rejected or retried rather than accepted, increasing visible sync/planning errors but improving correctness.
- Operational complexity increases for production WebDAV due to Apache migration and conditional-write configuration hardening.
- Required edge-case handling includes: repeated concurrent edits during replan window, hash mismatch churn causing retry exhaustion, stale mobile cache pushes, missing/weak conditional headers, and conflict logging/auditability.
- Non-goals (out of scope): changing LLM prompts or scheduling policy logic, modifying purge semantics, altering Certbot challenge type (still HTTP-01), enabling TLS in integration test WebDAV, changing cert mount roots, and adding integration tests that invoke paid LLM calls beyond existing policy.

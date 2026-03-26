## Context

The daemon currently protects `tasks.org` writes with atomic rename, but this only prevents partial
file corruption. It does not prevent stale-read overwrite when two writers race (daemon Pass 2 and
mobile WebDAV sync). Today, concurrent writes can still collapse into silent last-writer-wins.

This change introduces explicit conflict detection at both write boundaries:
- Daemon planner append path (`two-pass-scheduling` / `atomic-tasks-org-update`)
- Production WebDAV upload path (`webdav-sync` / `webdav-tls`)

Operational constraints must remain stable:
- Keep production TLS contract (`WEBDAV_DOMAIN`, Certbot HTTP-01, `/etc/letsencrypt:/certs:ro,z`)
- Keep integration test WebDAV non-TLS and deterministic (`docker-compose.test.yml` override model)
- Avoid paid integration test expansion and preserve existing test runner assumptions

## Goals / Non-Goals

**Goals:**
- Convert silent overwrite behavior into explicit conflict outcomes across daemon and WebDAV paths.
- Ensure Pass 2 planning appends only when base file version is still valid, otherwise replan.
- Enforce stale-write rejection for production WebDAV client pushes via conditional requests.
- Bound retry behavior to avoid livelock and produce deterministic logs for operations/debugging.
- Preserve existing production TLS and Certbot operational behavior.

**Non-Goals:**
- Changing scheduling policy or LLM prompt semantics beyond conflict-aware replan flow.
- Changing purge logic, inbox routing model, or unrelated daemon architecture.
- Switching Certbot challenge type or cert storage topology.
- Enabling TLS in integration test WebDAV.
- Adding new paid LLM integration test requirements.

## Decisions

1. Use content-hash optimistic concurrency for daemon Pass 2 append.
   - Decision: Compute a sha256 hash of `tasks.org` before Pass 2 context build, re-check just before
     append, and only append if unchanged.
   - On mismatch: Re-read latest file, rebuild Pass 2 context, rerun planning, retry up to a bounded
     max-attempt count.
   - Why: Keeps conflict detection local to existing file-oriented architecture with minimal additional
     state and deterministic behavior.
   - Alternatives considered:
     - File locking across daemon and WebDAV: rejected because lock coordination across independent
       sync clients is brittle and does not protect out-of-process remote uploads.
     - Always merge by patching sections: rejected for complexity/risk in org structural merges and
       higher chance of semantic corruption.

2. Treat retry exhaustion as explicit non-success, never silent fallback append.
   - Decision: After max retries, abort write and emit conflict failure logs/events.
   - Why: Correctness over liveness for contested writes; silent success would reintroduce data-loss
     risk and hide contention.
   - Alternatives considered:
     - Unbounded retries: rejected due to livelock risk and daemon throughput impact.
     - Best-effort append after mismatch: rejected because it violates conflict-safety guarantees.

3. Migrate production WebDAV backend from `hacdias/webdav` to Apache `httpd` + `mod_dav`.
   - Decision: Use Apache for production WebDAV so conditional request semantics can reject stale
     writes reliably (`If-Match`/precondition failure behavior).
   - Why: Apache `mod_dav` has mature conditional write handling needed for explicit stale-write
     rejection.
   - Alternatives considered:
     - Keep `hacdias/webdav` and front with proxy logic: rejected due to uncertain precondition
       enforcement guarantees and increased moving parts.
     - Add custom write-gateway service: rejected for unnecessary operational surface area.

4. Preserve existing TLS/certificate contract while changing WebDAV runtime.
   - Decision: Keep cert mount path, domain-driven certificate resolution, and Certbot renewal/restart
     workflow unchanged from operator perspective.
   - Why: Limits migration risk and avoids changing validated operational playbooks.
   - Alternatives considered:
     - Rework full TLS topology during backend migration: rejected as out of scope and high risk.

5. Keep integration override isolated from production runtime requirements.
   - Decision: Test compose override continues to run non-TLS WebDAV without Certbot/host cert deps,
     and without requiring production Apache conditional-write setup.
   - Why: Preserves deterministic CI/manual integration execution and existing assertions.
   - Alternatives considered:
     - Align test runtime to production TLS stack: rejected due to unnecessary complexity and env
       coupling for current test goals.

## Risks / Trade-offs

- [Higher visible write failures under contention] -> Mitigation: bounded retry + clear operator logs;
  document pull-before-push behavior for clients.
- [Retry churn can delay planner throughput] -> Mitigation: conservative retry cap with fast failure;
  monitor conflict frequency and tune cap.
- [Apache migration introduces config/ops drift risk] -> Mitigation: preserve existing mount/env
  contract and validate with compose smoke checks.
- [Client ecosystem may send weak/missing conditional headers] -> Mitigation: enforce precondition
  semantics and document expected client sync behavior; treat missing/invalid as explicit failure.
- [Two independent conflict systems (daemon + WebDAV) increase complexity] -> Mitigation: centralized,
  deterministic conflict logging taxonomy across modules (`core`, `router`, `git-sync`/WebDAV paths).

## Migration Plan

1. Implement daemon conflict-aware Pass 2 append flow with hash verify, replan, bounded retries, and
   explicit failure status logging.
2. Add/adjust capability specs for new and modified behavior (`tasks-org-conflict-aware-planning`,
   `webdav-conditional-write-rejection`, plus listed modified capabilities).
3. Introduce Apache production WebDAV container/config with conditional write rejection enabled while
   preserving existing TLS cert mount and domain path behavior.
4. Update production compose/runtime wiring to point WebDAV service to Apache implementation; keep
   Certbot integration unchanged.
5. Validate integration override still runs non-TLS and independent of production cert/TLS concerns.
6. Rollout with log monitoring for conflict outcomes; if severe regressions occur, rollback by
   restoring prior WebDAV container image/config and disabling planner conflict enforcement behind
   guarded config toggle only if emergency requires temporary compatibility.

Rollback strategy:
- Revert compose/service definitions to prior `hacdias/webdav` production setup.
- Revert daemon conflict-enforcement changes if they block critical operation, while accepting
  temporary reintroduction of overwrite risk until fixed.

## Open Questions

- What exact retry cap and backoff (if any) should Pass 2 use to balance throughput vs. conflict
  convergence?
- Should planner conflict failures surface to a dedicated DLQ-like artifact or stay in structured logs
  only?
- Which conditional header policy should be mandated for mobile clients when headers are absent or
  weak validators are used?
- Do we need a feature flag for staged Apache rollout, or is direct cutover acceptable in production?

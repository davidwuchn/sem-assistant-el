## Context

The SEM daemon is orchestrated by cron-invoked `emacsclient` entry points. Today, overlapping invocations can run concurrently when an earlier run exceeds the schedule interval, which increases duplicate processing and race-prone writes to shared org artifacts. We also have a documentation/runtime mismatch for URL defanging behavior, especially around expectations for `sem-security-sanitize-urls` and output surfaces (task routing, RSS digests, and URL capture flows).

This change introduces two cross-cutting requirements:
- A deterministic overlap policy for cron-triggered jobs, with stale-lock and crash recovery semantics.
- A single authoritative URL-defanging contract that docs and runtime behavior both follow.

Constraints:
- Preserve existing trust boundary assumptions and single-user deployment model.
- Reuse existing operational logging channels for observability.
- Avoid introducing deadlock between independent scheduled jobs.

## Goals / Non-Goals

**Goals:**
- Guarantee one active execution per guarded cron job at a time.
- Make overlap outcomes deterministic (skip or serialize by explicit policy) and observable in logs.
- Define recovery behavior for stale lock artifacts and crashed holders.
- Align URL defanging documentation with actual runtime behavior so operator expectations match production behavior.

**Non-Goals:**
- Changing sensitive-content tokenization semantics or DLQ policy.
- Introducing a new log storage tier or distributed lock service.
- Expanding from single-user tenancy assumptions.
- Redesigning unrelated scheduling logic outside guarded cron entry points.

## Decisions

1. Lock-file based per-job guard with lease metadata.
   - Decision: Use a per-job lock artifact with holder metadata (pid/process identity, creation timestamp, heartbeat or mtime freshness signal) to enforce single active execution.
   - Rationale: Fits current local single-node deployment, avoids new dependencies, and is straightforward to inspect operationally.
   - Alternatives considered:
     - In-memory mutex only: rejected because cron invocations are process-isolated.
     - External lock service (Redis/DB): rejected as unnecessary operational overhead.

2. Policy is explicit per guarded job: default `skip` on contention.
   - Decision: Define policy at guard registration time, defaulting to skip-and-log for periodic jobs; allow explicit serialize mode only where backlog processing is required.
   - Rationale: Prevents queue amplification for high-frequency jobs while allowing controlled serialization for critical catch-up flows.
   - Alternatives considered:
     - Always serialize: rejected due to unbounded backlog risk.
     - Always skip: rejected because some flows need guaranteed eventual execution.

3. Stale-lock recovery with bounded age and verification.
   - Decision: Treat locks older than a configured TTL as candidates for recovery; before takeover, verify holder liveness where possible and emit a structured recovery log event.
   - Rationale: Handles crash/restart scenarios without permanent blockage and keeps behavior predictable after host interruptions.
   - Alternatives considered:
     - Never reclaim: rejected due to stuck jobs after crashes.
     - Immediate reclaim without checks: rejected because it risks split-brain execution during transient pauses.

4. Guard scope is job-local, not global.
   - Decision: Lock namespace keys by logical job identity so independent jobs do not block each other.
   - Rationale: Preserves throughput and avoids accidental global deadlock.
   - Alternatives considered:
     - Single global lock: rejected because unrelated jobs would serialize unnecessarily.

5. URL-defanging contract is centralized in documentation and validated at call sites.
   - Decision: Document one canonical behavior for when URLs are defanged versus preserved, and align all behavior statements (and any contradictory inline docs) to that contract.
   - Rationale: Eliminates operator ambiguity and incident-review confusion.
   - Alternatives considered:
     - Per-module ad hoc docs: rejected because drift already occurred under this model.

## Risks / Trade-offs

- [False stale detection under clock skew or long GC pauses] -> Use conservative TTL defaults, monotonic time where available, and log lock age/holder metadata for diagnosis.
- [Serialize mode can increase latency and queue depth] -> Restrict serialize usage to explicitly identified jobs and keep skip as default.
- [Lock-file corruption or partial write during crash] -> Use atomic write/rename patterns and robust parse fallback to safe contention handling.
- [Behavior drift between docs and runtime returns over time] -> Add explicit contract section and require updates alongside runtime changes touching defanging behavior.

## Migration Plan

1. Introduce guard primitives and per-job policy wiring behind existing cron entry points.
2. Roll out logging fields for contention, skip, acquire, reclaim, and release events.
3. Update URL-defanging docs and module-level behavior descriptions to one authoritative contract.
4. Validate in staging/local daemon runs: overlap attempts produce deterministic outcomes and expected logs.
5. Deploy incrementally with conservative stale TTL; monitor for excessive reclaim/skip events.

Rollback:
- Revert guard wiring for affected jobs to prior invocation behavior.
- Retain doc clarifications that are still accurate; if behavior is reverted, immediately update docs in the same rollback change.

## Open Questions

- Which specific cron jobs require `serialize` instead of default `skip`?
- What stale-lock TTL is acceptable per job class (high-frequency vs long-running)?
- Do we need a lightweight heartbeat update, or is lock mtime refresh sufficient for liveness?
- Should guard events include a stable correlation id to improve restart-incident tracing?

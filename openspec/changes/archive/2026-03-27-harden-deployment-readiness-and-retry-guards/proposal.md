## Why

Deployment and runtime behavior contain mismatch paths that can fail first boot, silently disable weak-tier model selection, and allow unbounded retry loops. These gaps increase operational risk, API cost, and readiness false-positives for a personal always-on service.

## What Changes

- Align documented bootstrap order with WebDAV runtime preconditions (certificates + production password policy) so first-run behavior is deterministic.
- Ensure weak-tier model environment wiring is explicit in container runtime so documented model-tier behavior is actually active.
- Add bounded retry + DLQ behavior for task LLM API-failure paths to prevent infinite retry churn.
- Tighten planner scheduling-decision parsing to avoid cross-line misassociation for mixed `SCHEDULED` and `(unscheduled)` outputs.
- Tighten startup readiness invariant semantics so dependency load failures cannot be reported as healthy startup.

## Capabilities

### New Capabilities

- `task-llm-bounded-retry-dlq`: Task LLM API-failure handling MUST increment retry state, stop retrying after the configured cap, and route terminal failures to DLQ; malformed output handling remains distinct from API-failure handling.

### Modified Capabilities

- `webdav-tls`: Bootstrap and deployment documentation MUST require certificate issuance/verification before production WebDAV startup paths that enforce TLS cert readability.
- `production-webdav-password-policy`: Default/example credential guidance MUST never suggest non-compliant passwords in production paths.
- `flow-model-tier-selection`: Runtime container environment MUST include optional weak-tier model variable wiring; unset/empty weak-tier behavior MUST continue to fall back to medium-tier.
- `two-pass-scheduling`: Pass 2 decision parsing MUST be line-scoped and deterministic; each decision line maps exactly one task ID to exactly one scheduling outcome without scanning into unrelated lines.
- `daemon-readiness-probe`: Readiness success MUST require successful completion of dependency-load invariants; logged dependency-load failures MUST block healthy readiness state.

## Impact

- Reduces first-run deployment failure ambiguity and startup false-green states.
- Reduces runaway API retry spend and repeated processing churn.
- Improves scheduling correctness under mixed planner outputs.
- Clarifies operator expectations in docs for secure WebDAV startup.
- Out of scope: changing cron cadence, changing LLM prompt content, redesigning Git sync behavior, or introducing new external infrastructure.

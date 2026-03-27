## Context

This change hardens reliability and deployment safety for a long-running personal Emacs daemon
that integrates WebDAV, LLM task processing, and readiness signaling. Current behavior has five
high-impact gaps: documentation can lead operators into failing first-boot WebDAV states, weak
tier model selection is documented but not consistently wired at container runtime, task retries
on API failure can churn without a terminal guard, scheduling-decision parsing can misassociate
outputs across lines, and startup can report healthy readiness despite dependency-load failures.

Constraints:
- Keep existing module boundaries and architecture (`sem-core`, `sem-router`, startup/init flow).
- Preserve behavior for malformed LLM output paths distinct from API-failure paths.
- Avoid adding external infrastructure or changing steady-state cron cadence.
- Maintain secure-by-default operator guidance for production WebDAV startup.

## Goals / Non-Goals

**Goals:**
- Make first-run WebDAV deployment behavior deterministic by aligning bootstrap sequence with TLS
  cert and production password requirements.
- Ensure weak-tier model behavior is truly active when configured, while preserving fallback to
  medium-tier when weak-tier is unset.
- Enforce bounded retries and terminal DLQ routing for task LLM API failures.
- Make pass-2 scheduling parsing line-scoped and deterministic for mixed `SCHEDULED`/
  `(unscheduled)` outputs.
- Require dependency-load invariants for startup readiness success.

**Non-Goals:**
- Changing cron frequencies or job orchestration cadence.
- Redesigning prompts or planner strategy.
- Reworking git-sync behavior.
- Introducing new external services, queues, or storage backends.

## Decisions

1. Documentation-first deployment invariants for WebDAV startup
- Decision: Update bootstrap/deployment docs so production startup paths explicitly require
  certificate issuance/verification and compliant password guidance before runtime startup.
- Rationale: Current mismatch between docs and runtime preconditions causes avoidable first-boot
  failures and operator confusion.
- Alternatives considered:
  - Relax runtime preconditions to match loose docs: rejected; weakens security guarantees.
  - Auto-generate certs in daemon startup: rejected; adds hidden side effects and complexity.

2. Explicit container wiring for weak-tier model selection
- Decision: Ensure runtime container environment passes optional weak-tier model variable through
  to the daemon process.
- Rationale: The selection contract should be executable, not only documented.
- Alternatives considered:
  - Infer weak-tier from medium-tier internally without env wiring: rejected; hides config intent.
  - Introduce a new config file source: rejected; unnecessary indirection for this change.

3. Bounded API-failure retry with terminal DLQ transition
- Decision: For task LLM API failures, increment retry state per attempt, enforce configured max,
  then route terminal failures to DLQ. Keep malformed-output handling as a separate path.
- Rationale: Prevent infinite churn and unbounded API cost while preserving diagnosability.
- Alternatives considered:
  - Global retry watchdog outside task path: rejected; less precise and harder to reason about.
  - Immediate DLQ on first API error: rejected; too aggressive for transient provider failures.

4. Deterministic line-scoped pass-2 scheduling parser
- Decision: Parse planner decisions one line at a time; each line can map exactly one task ID to
  exactly one outcome (`SCHEDULED` or `(unscheduled)`) without scanning neighboring lines.
- Rationale: Eliminates cross-line misassociation in mixed output and improves correctness.
- Alternatives considered:
  - Keep permissive multiline extraction with heuristics: rejected; remains fragile and ambiguous.
  - Require strict JSON output from planner: rejected for now; larger prompt/protocol change.

5. Readiness success gated by dependency-load invariants
- Decision: Startup readiness reports healthy only if dependency-load invariants complete
  successfully; logged dependency-load failures force non-ready state.
- Rationale: Avoid false-green startup states that hide broken runtime capability.
- Alternatives considered:
  - Keep current readiness and rely on logs: rejected; operators need a trustworthy probe.
  - Add a second "degraded" readiness channel only: deferred; useful but outside minimal fix scope.

## Risks / Trade-offs

- [Stricter readiness can increase startup failures] -> Mitigation: provide explicit failure logs
  and deterministic remediation guidance in docs.
- [Retry cap may route recoverable issues to DLQ in long outages] -> Mitigation: make cap
  configurable and preserve clear reprocessing workflow from DLQ.
- [Line-scoped parser may ignore unconventional planner formats] -> Mitigation: keep parsing rules
  explicit, test mixed-format examples, and treat unknown lines as non-actions.
- [Doc/runtime alignment requires coordinated updates] -> Mitigation: include doc validation in
  change review checklist.

## Migration Plan

1. Land documentation updates for WebDAV TLS/password preconditions and runtime model-tier wiring.
2. Implement weak-tier env pass-through in container/runtime configuration.
3. Implement bounded API-failure retry + terminal DLQ transition in task processing path.
4. Replace pass-2 decision parser with line-scoped deterministic mapping.
5. Gate readiness success on dependency-load invariants and add/adjust tests.
6. Rollback strategy: revert individual hardening commits in reverse order; if readiness gating
   causes unacceptable operational disruption, temporarily restore prior readiness semantics while
   retaining logging and retry safeguards.

## Open Questions

- What should the default API-failure retry cap be for this deployment profile (cost vs resiliency)?
- Should readiness expose structured failure reasons (for automation) in addition to logs?
- Do we want a future strict planner decision format (e.g., JSON) to further reduce parser drift?

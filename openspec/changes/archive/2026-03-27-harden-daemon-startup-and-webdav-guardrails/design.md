## Context

The daemon currently has three related reliability gaps during startup and planning execution.
First, Pass 2 planning can explicitly return a non-success outcome after Pass 1 has already
generated tasks in temporary files, which allows stale-temp cleanup to delete recoverable work.
Second, health signaling is process-centric (liveness) instead of function-centric (workflow
readiness), so partial initialization failures can still look healthy to probes. Third, the
container startup path can continue into keepalive/tail behavior after startup failure,
masking broken state and delaying restart/recovery loops.

Security validation for WebDAV credentials is also under-constrained for production-like
deployments. A weak default value can accidentally pass into internet-exposed use.

The proposal defines a single direction: make failure states explicit, deterministic, and
visible, while preserving existing integration-test behavior.

## Goals / Non-Goals

**Goals:**
- Prevent silent task loss when Pass 2 planning returns a non-success result.
- Introduce a lightweight SEM readiness contract that reflects functional startup state.
- Unify watchdog and entrypoint health gating around that readiness contract.
- Enforce production-only WebDAV password policy (length/complexity) with fast-fail startup.
- Keep probe execution cheap and safe for frequent invocation.
- Preserve integration-test compatibility by exempting non-production/test runtime paths.

**Non-Goals:**
- Redesign planning quality heuristics or scheduling policy.
- Add heavyweight startup checks (network calls, full workflow execution).
- Introduce external secret managers or credential rotation workflows.
- Rework integration test architecture beyond compatibility guarantees.

## Decisions

1. **Adopt Pass 1 fallback semantics on explicit Pass 2 non-success.**
   - **Decision:** Treat explicit Pass 2 non-success as a controlled fallback case: preserve
     Pass 1 generated tasks and route outcome through existing failure surfacing/logging so
     output is either persisted or explicitly marked failed.
   - **Why:** Generated tasks are already useful intermediate output; deleting them via temp
     cleanup creates silent data loss and breaks operator trust.
   - **Alternatives considered:**
     - Hard-fail and delete temporary output: rejected because it preserves correctness at the
       cost of avoidable user-visible data loss.
     - Auto-retry Pass 2 indefinitely: rejected due to increased runtime uncertainty and
       potential repeated failures without improving observability.

2. **Introduce a dedicated readiness function in Elisp with deterministic criteria.**
   - **Decision:** Add a lightweight readiness probe function that evaluates critical startup
     invariants (module/dependency initialization completion and required state) without
     executing workflows or external I/O.
   - **Why:** A single source of truth for readiness removes drift between monitoring surfaces
     and gives deterministic semantics for restart policy.
   - **Alternatives considered:**
     - Continue using daemon liveness only: rejected because process-up != workflow-ready.
     - Run a synthetic workflow as probe: rejected as too expensive and side-effect-prone.

3. **Use readiness (not liveness) for watchdog and entrypoint startup gating.**
   - **Decision:** Replace watchdog health checks with readiness checks and gate entrypoint
     keepalive/tail on a successful readiness result.
   - **Why:** Aligning both components to the same contract prevents one layer from masking
     failures detected by another and makes container state reflect actual service usability.
   - **Alternatives considered:**
     - Keep watchdog on liveness and entrypoint on readiness: rejected due to split-brain
       health semantics.
     - Keep entrypoint behavior unchanged: rejected because startup failures remain hidden.

4. **Enforce production-only WebDAV password policy at startup.**
   - **Decision:** Add startup validation that, in production mode only, rejects passwords that
     do not meet minimum policy (>= 20 chars, includes lowercase, uppercase, digit).
   - **Why:** This blocks unsafe default/weak credentials before exposing WebDAV endpoints.
   - **Alternatives considered:**
     - Enforce policy in all environments: rejected because it breaks test/dev ergonomics.
     - Warn-only policy: rejected because warnings are easy to ignore and do not prevent risk.

5. **Keep policy and readiness checks explicit and centrally logged.**
   - **Decision:** Route readiness and password validation failures through existing structured
     logging/error channels so operational diagnostics remain consistent.
   - **Why:** Startup hardening is only effective if failures are immediately visible and
     attributable.
   - **Alternatives considered:**
     - Ad-hoc `message`-only diagnostics: rejected because they are less structured and harder
       to alert on.

## Risks / Trade-offs

- **[Readiness false negatives due to strict invariants]** -> Mitigation: keep readiness
  criteria minimal and tied only to mandatory startup prerequisites; document invariants.
- **[Readiness false positives if invariants are incomplete]** -> Mitigation: centralize
  readiness criteria in one function and cover with focused ERT tests.
- **[Fallback semantics may preserve low-quality partial tasks]** -> Mitigation: mark non-success
  path explicitly in logs/status so operators can review and rerun planning.
- **[Production-mode detection mistakes could over/under-enforce password policy]** -> Mitigation:
  define explicit environment guard conditions and add tests for production vs test modes.
- **[Startup fast-fail can increase restart loops when misconfigured]** -> Mitigation: emit clear
  validation error messages so configuration fixes are straightforward.

## Migration Plan

1. Implement readiness probe function and tests for ready/not-ready criteria.
2. Switch watchdog check path from liveness to readiness.
3. Update container entrypoint startup gate to require readiness success before keepalive/tail.
4. Implement production-only WebDAV password validation and tests (production + test exemptions).
5. Implement Pass 2 non-success fallback preservation path and regression tests for task-loss
   prevention.
6. Validate end-to-end startup behavior via existing non-integration test workflows and maintain
   integration-flow compatibility assumptions.
7. Rollback strategy: revert readiness gating and password enforcement commits independently if
   they cause operational regressions; fallback to previous liveness-only startup behavior.

## Open Questions

- Which exact startup invariants should be considered mandatory for readiness in this repository
  (module load completion only vs additional file/path checks)?
- What is the canonical production-mode signal (`ENV`, explicit flag, or both) to avoid
  ambiguity in password-policy enforcement?
- Should readiness failure details expose granular reasons externally, or remain internal logs
  with binary probe output?

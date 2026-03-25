## Context

URL capture runs inside a long-lived Emacs daemon and currently depends on lower-level
network/subprocess behavior for termination. The proposal introduces a hard operational
contract: each URL-capture attempt must complete (success or fail) within 5 minutes of
wall-clock time. The change must preserve existing retry controls and avoid introducing
new retry-loop behavior.

Relevant modules are `sem-url-capture.el` (capture pipeline/orchestration), `sem-router.el`
(routing and retry decisions), and `sem-core.el` (logging and retry bookkeeping).

## Goals / Non-Goals

**Goals:**
- Enforce a single end-to-end timeout budget of 5 minutes per capture attempt.
- Treat timeout as a distinct `FAIL` outcome with explicit timeout logging.
- Keep timeout failures retryable under existing retry policy and counters.
- Prevent timeout handling from marking links as permanently processed.

**Non-Goals:**
- Changing retry limits, backoff strategy, or schedule semantics.
- Reworking task routing/LLM behavior outside URL capture timeout paths.
- Introducing new external services, queues, or distributed coordination.

## Decisions

1. Introduce explicit deadline orchestration at the top-level capture flow.
   - Decision: Wrap URL-capture execution in an orchestrator-level timeout guard that
     measures wall-clock time for the entire attempt.
   - Rationale: Per-step timeouts (download only or subprocess only) do not guarantee
     total bounded latency when multiple steps stall independently.
   - Alternative considered: Rely only on subprocess/network-level timeout flags.
     Rejected because cumulative hangs can still exceed the 5-minute SLA.

2. Normalize timeout into a first-class failure type.
   - Decision: Map timeout expiration to a dedicated timeout failure branch that logs
     with `FAIL` status and timeout-specific message content.
   - Rationale: Operators need to distinguish timeout failures from parsing/content
     errors to diagnose infra vs. data issues.
   - Alternative considered: Reuse generic error handling and messages.
     Rejected because timeout observability becomes inconsistent and hard to query.

3. Preserve retry eligibility by aligning timeout handling with existing retry flow.
   - Decision: Timeout failure updates retry bookkeeping exactly like other retryable
     failures and avoids writing success/processed markers.
   - Rationale: Proposal requires timeout to remain retryable without policy changes.
   - Alternative considered: Mark timed-out links as terminal failures.
     Rejected because it violates the explicit retry contract in the proposal.

4. Keep timeout configuration centralized and deterministic.
   - Decision: Define a single timeout constant in URL-capture flow and pass it to any
     lower-level operations that support bounded execution.
   - Rationale: One source of truth prevents drift between orchestration and child-step
     limits, reducing accidental overrun.
   - Alternative considered: Independent timeout values per subsystem.
     Rejected because mismatched values complicate reasoning and test coverage.

## Risks / Trade-offs

- [Risk] Timeout interrupts may race with late-arriving subprocess output ->
  Mitigation: Make completion writes/idempotent state transitions happen only in the
  success path after timeout checks.
- [Risk] Overly strict timeout may drop legitimate long-running captures ->
  Mitigation: Keep timeout at the proposal-defined 5-minute contract and log enough
  context to tune later if requirements change.
- [Risk] Divergent timeout behavior across modules ->
  Mitigation: Add tests for end-to-end timeout classification and retry eligibility
  through router + url-capture boundaries.
- [Risk] Hidden regressions in retry accounting ->
  Mitigation: Extend ERT tests to validate retry counters/flags for timeout cases.

## Migration Plan

1. Add/adjust timeout guard in URL-capture orchestration and map timeout to explicit
   `FAIL` result.
2. Wire timeout result into router retry path without changing retry policy settings.
3. Add focused unit tests for timeout classification, logging, and retry eligibility.
4. Run existing test suite (`eask test ert app/elisp/tests/sem-test-runner.el`) and
   ensure no behavior changes outside timeout paths.

Rollback strategy: revert timeout-specific orchestration and classification changes;
retry behavior falls back to previous generic-error handling.

## Open Questions

- Should timeout logs include elapsed milliseconds in addition to high-level status for
  easier postmortem correlation?
- Do we need separate timeout labels for download-stage vs orchestration-stage timeout,
  or is a single timeout category sufficient for current operations?

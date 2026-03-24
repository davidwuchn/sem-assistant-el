## Context

The planning flow currently allows Pass 2 outputs to include scheduled timestamps that are
already in the past relative to runtime. This violates scheduling intent and has produced
regressions (for example, year-2024 timestamps). The proposal defines a strict runtime lower
bound: generated scheduled starts must be greater than runtime-now-plus-one-hour.

The integration suite currently validates keyword and sensitive-content behavior, but does not
enforce this temporal constraint. The change also introduces one explicit exception:
`Process quarterly financial reports` must preserve the exact timestamp declared in
`dev/integration/testing-resources/inbox-tasks.org`.

Primary constraints:
- Keep existing task generation and scheduling heuristics unchanged.
- Preserve current inbox task fixtures except for enforcing the named exception rule.
- Avoid unit-test regressions while adding deterministic integration assertions.

## Goals / Non-Goals

**Goals:**
- Add an unambiguous lower-bound scheduling rule to Pass 2 planning inputs.
- Ensure deterministic datetime comparison semantics for integration validation.
- Enforce strict `>` lower-bound checks for generated scheduled tasks.
- Enforce exact equality for the fixed-schedule exception task.
- Keep timezone handling consistent by using one runtime timezone authority per test run.

**Non-Goals:**
- Rewriting scheduling strategy or LLM prompt architecture outside the bound instruction.
- Modifying inbox task content or fixture semantics beyond the named exception.
- Broad refactors of integration harness components unrelated to timestamp assertions.

## Decisions

1. Runtime bound is computed once per run and propagated to Pass 2.
   - Decision: Compute `runtime_now` and `runtime_min_start = runtime_now + 1 hour` once at
     integration runtime and include both values in Pass 2 planning context.
   - Rationale: Single-source runtime values avoid drift and cross-check ambiguity.
   - Alternatives considered:
     - Recompute in multiple call sites: rejected due to inconsistent comparisons and edge drift.
     - Provide only `runtime_now`: rejected because lower-bound intent becomes implicit.

2. Lower-bound semantics are strict greater-than.
   - Decision: A scheduled timestamp is valid only when `scheduled_start > runtime_min_start`.
   - Rationale: Proposal requires strict inequality; this closes boundary loopholes at exact +1h.
   - Alternatives considered:
     - Greater-than-or-equal (`>=`): rejected because it weakens the required guardrail.

3. Exception handling is task-name based and equality-checked.
   - Decision: For title `Process quarterly financial reports`, assert exact timestamp equality
     against the inbox fixture and bypass the lower-bound check for that task only.
   - Rationale: Preserves deterministic fixed-schedule behavior while keeping global rule strict.
   - Alternatives considered:
     - Global allowlist by tag: rejected due to wider blast radius and weaker intent clarity.
     - No exception: rejected because proposal explicitly requires this carve-out.

4. Datetime normalization is explicit before comparison.
   - Decision: Parse planned timestamps and runtime bound into normalized comparable forms in the
     same timezone authority before ordering/equality checks.
   - Rationale: Prevents false negatives from representation differences (offset/format variants).
   - Alternatives considered:
     - String comparison: rejected as non-semantic and format-sensitive.
     - Mixed local/system timezone fallback: rejected due to nondeterministic behavior.

5. Assertion scope extends integration assertion set only.
   - Decision: Add/adjust integration assertions (Assertion 2 and fixed-schedule checks) without
     invoking paid integration execution from agent workflows.
   - Rationale: Aligns with project guardrails and keeps verification deterministic in CI/manual runs.
   - Alternatives considered:
     - Add only prompt changes without assertions: rejected because regressions remain undetected.

## Risks / Trade-offs

- [Clock boundary flakiness near second transitions] -> Mitigate by computing runtime bounds once
  and comparing against normalized parsed timestamps.
- [Timezone mismatch between generated plan and test parser] -> Mitigate by defining one runtime
  timezone authority and normalizing all parsed datetimes into that authority.
- [False failure for exception task if title parsing changes] -> Mitigate by asserting against exact
  canonical task title used in fixture and covering name-matching behavior in tests.
- [Increased assertion complexity in integration script/spec docs] -> Mitigate with focused helper
  functions and mirrored documentation updates for constants/arrays.

## Migration Plan

1. Update Pass 2 planning context construction to include runtime-now and runtime-min-start.
2. Update planning prompt/instruction text to require strict lower-bound scheduling semantics.
3. Extend integration assertion logic to:
   - Validate strict lower-bound ordering for non-exception scheduled tasks.
   - Validate exact equality for `Process quarterly financial reports`.
4. Update assertion documentation/spec references to match implementation constants.
5. Run repository test suite (excluding paid integration execution) to confirm no regressions.

Rollback strategy:
- Revert assertion and planning-context changes together if unexpected instability appears.
- Keep exception rule and lower-bound logic in sync to avoid partial-policy behavior.

## Open Questions

- Should the fixed-schedule exception be matched strictly by title only, or title plus tags for
  additional safety if similarly named tasks appear later?
- Should parsed datetimes with missing timezone offsets be treated as invalid input (fail fast) or
  interpreted in runtime timezone authority?

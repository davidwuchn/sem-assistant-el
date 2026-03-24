## Context

The current task capture pipeline relies on a two-pass LLM workflow where Pass 1 normalizes raw inbox text and Pass 2 performs planning/scheduling. Today, Pass 1 behavior is under-specified for mobile shorthand (for example, misspellings, relative time phrases, urgency markers, and noisy punctuation), which leads to inconsistent TODO structure and weak planning input.

This change improves only the Pass 1 prompt contract and associated validation/test coverage. It does not replace Pass 2 planning policy, add calendar integrations, or introduce a deterministic NLP parser. The implementation must preserve existing daemon resiliency guarantees (no crash propagation, safe fallback behavior, and stable output format expectations used by downstream modules and tests).

## Goals / Non-Goals

**Goals:**
- Make Pass 1 normalization deterministic enough for noisy mobile capture by adding explicit, example-driven extraction rules for title cleanup, priority, schedule hints, and duration handling.
- Preserve meaningful body content without forcing single-line compression; allow multi-line body output when source input is multi-line.
- Ensure final normalized tasks always have priority via deterministic fallback (`[#C]`) when Pass 1 omits priority.
- Anchor relative date/time interpretation using runtime current datetime included in prompt context.
- Preserve optional scheduling semantics: Pass 1 may leave tasks unscheduled when confidence is low, and Pass 2 remains authoritative for final placement.
- Add integration-style fixtures/assertions that lock in shorthand parsing and fallback invariants.

**Non-Goals:**
- Changing Pass 2 planner strategy or moving scheduling authority away from Pass 2.
- Expanding or changing allowed tag sets and unrelated task formatting policies.
- Building locale-complete linguistic parsing beyond targeted prompt examples.
- Introducing new external dependencies or non-LLM preprocessing pipelines.

## Decisions

1. Strengthen Pass 1 system prompt as the primary control surface
- Decision: encode normalization policy, urgency mapping, and shorthand schedule parsing directly in Pass 1 prompt text with concrete examples.
- Rationale: this is the lowest-risk path that fits the existing architecture and avoids new runtime dependencies.
- Alternative considered: pre-process notes with deterministic regex/NLP before LLM call. Rejected for now due to complexity, maintenance burden, and out-of-scope constraints.

2. Allow optional LLM priority with deterministic post-defaulting
- Decision: Pass 1 may omit priority in raw output; normalization post-processing guarantees one final priority token by inserting `[#C]` when missing.
- Rationale: keeps prompt behavior flexible while preserving deterministic planner inputs and eliminating missing-priority outputs in final tasks.
- Alternative considered: require strict always-on priority generation from LLM only. Rejected because omission can still happen in noisy inputs and should be handled safely in validation/defaulting.

3. Pass runtime current datetime into Pass 1 prompt context
- Decision: include an explicit "now" reference in prompt input for each normalization request.
- Rationale: relative phrases (for example, "tomorrow", weekday names, "next week") require a deterministic anchor to avoid drift and test flakiness.
- Alternative considered: keep relative parsing implicit. Rejected due to inconsistent behavior across runs and contexts.

4. Keep schedule extraction best-effort and confidence-aware
- Decision: Pass 1 may omit schedule details when intent is ambiguous; unscheduled output remains valid.
- Rationale: avoids hallucinated scheduling and preserves current two-pass contract where planning is authoritative.
- Alternative considered: force always-on scheduling. Rejected because ambiguous notes are common in mobile capture and forced guesses reduce quality.

5. Apply a default duration of 30 minutes when time is present without duration
- Decision: when Pass 1 returns a schedule time but no explicit duration, downstream handling applies a 30-minute default block before planner stage.
- Rationale: provides a concrete minimum planning unit while keeping behavior predictable.
- Alternative considered: leave duration unset and let Pass 2 infer from title/body only. Rejected because it produces inconsistent slot sizes and weaker planner input.

6. Expand assertion coverage with mobile-shorthand fixtures
- Decision: add targeted integration assertions for ambiguous weekdays, misspellings (for example, "wendsday"), conflicting urgency markers, and preservation of identifiers like phone numbers.
- Rationale: these are high-frequency failure modes and need regression protection.
- Alternative considered: rely only on unit-level prompt string checks. Rejected because behavior-level assertions are needed to validate extraction outcomes and fallback invariants.

7. Do not force one-line body normalization
- Decision: Pass 1 body output may be multi-line when the raw capture contains multi-line context; normalization should improve clarity without collapsing structure.
- Rationale: forcing one-line bodies can discard signal and confuses extraction behavior for note-like captures.
- Alternative considered: always emit a single-line summary body. Rejected because it reduces fidelity for multi-line inputs and weakens planner context.

## Risks / Trade-offs

- [Prompt overfitting to examples] -> Keep examples representative but concise; validate with varied fixtures to avoid brittle pattern matching.
- [LLM output drift despite stronger instructions] -> Preserve strict post-parse validation and planner fallback paths; ensure failures degrade to safe unscheduled tasks.
- [Locale and spelling ambiguity still unresolved in edge cases] -> Document known ambiguity and treat uncertain cases as unscheduled rather than incorrectly scheduled.
- [Increased prompt length raises token cost/latency] -> Prioritize high-value examples only and avoid redundant wording.
- [Conflicting urgency markers may produce unstable mapping] -> Define deterministic precedence rule in specs/tests and assert expected mapping.

## Migration Plan

1. Update Pass 1 prompt text and runtime context injection in the existing LLM pipeline module.
2. Add/adjust normalization validation and default-duration handling where Pass 1 output is interpreted.
3. Extend assertion fixtures and integration checks for shorthand and fallback scenarios.
4. Run relevant ERT suite and targeted tests for routing/LLM pipeline behavior.
5. Roll out without schema/data migration since this is prompt/logic behavior only.

Rollback strategy:
- Revert prompt and assertion changes as a single change set if regressions appear.
- Because no persistent storage schema changes are introduced, rollback is code-only and immediate.

## Open Questions

- None at this stage. Priority fallback, weekday ambiguity handling, and misspelling behavior are now specified in delta specs.

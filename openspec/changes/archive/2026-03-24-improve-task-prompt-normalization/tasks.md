## 1. Pass 1 Prompt Contract Updates

- [x] 1.1 Update the Pass 1 task prompt text in `app/elisp/sem-prompts.el` to use explicit note-to-TODO transformation language with example-driven normalization rules.
- [x] 1.2 Add runtime current datetime injection to Pass 1 prompt assembly in the routing pipeline so relative phrases are anchored deterministically.
- [x] 1.3 Expand Pass 1 examples to cover shorthand and noisy inputs (`tomorrow`, `next week`, weekday variants, misspellings such as `wendsday`, urgency markers, and identifier-preservation cases).
- [x] 1.4 Ensure prompt guidance explicitly allows unscheduled output for ambiguous timing and allows multi-line body preservation.

## 2. Normalization and Fallback Behavior

- [x] 2.1 Update task-response normalization/validation to accept missing LLM priority and insert fallback `[#C]` before planner processing.
- [x] 2.2 Preserve a valid returned priority token when present, and replace invalid/unsupported priority tokens with `[#C]`.
- [x] 2.3 Implement/default duration handling so scheduled outputs without explicit duration are normalized to 30-minute blocks before Pass 2 input.
- [x] 2.4 Verify ambiguous weekday or low-confidence schedule interpretation paths keep tasks valid and unscheduled rather than forcing timestamps.

## 3. Tests and Assertions

- [x] 3.1 Add or update ERT coverage for Pass 1 prompt construction to assert runtime datetime context and new shorthand/edge-case instruction examples are present.
- [x] 3.2 Add or update ERT coverage for normalization behavior to verify priority fallback `[#C]`, valid-priority preservation, and invalid-priority replacement.
- [x] 3.3 Add or update ERT coverage for schedule fallback behavior to verify unscheduled acceptance on ambiguous timing and 30-minute default duration handling.
- [x] 3.4 Update integration test fixtures/assertion inputs for shorthand normalization edge cases (ambiguous weekdays, misspellings, conflicting urgency markers, identifier preservation).
- [x] 3.5 Update integration assertion keyword/constant arrays in `dev/integration/run-integration-tests.sh` and corresponding assertion spec references where new checks are introduced.

## 4. Verification and Change Hygiene

- [x] 4.1 Run targeted ERT files covering router, prompt, and normalization behavior and fix any regressions.
- [x] 4.2 Run full ERT suite via `eask test ert app/elisp/tests/sem-test-runner.el`.
- [x] 4.3 Re-check OpenSpec artifacts for consistency (`proposal.md`, `design.md`, `specs/**`) against implemented behavior before handoff.

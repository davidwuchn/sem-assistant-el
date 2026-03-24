## Why

Planning can produce timestamps in the past (for example, year 2024), which violates scheduling intent and causes invalid plans. Integration tests currently do not enforce a runtime lower bound for planned timestamps, so regressions can pass undetected.

## What Changes

- Add an explicit runtime time-bound requirement to Pass 2 planning inputs: scheduling decisions must start strictly after the run's current datetime plus one hour.
- Add integration-test assertions that verify generated scheduled start times are greater than the test run's current datetime.
- Add one explicit exception: `Process quarterly financial reports` must preserve the exact scheduled timestamp defined in `dev/integration/testing-resources/inbox-tasks.org`.
- Define deterministic comparison rules for timestamp validation, including timezone source, strict inequality semantics, and exception handling.

## Capabilities

### New Capabilities

- `integration-scheduled-time-lower-bound-assertion`: Integration flow validates that each generated scheduled task starts after runtime-now-plus-one-hour, except the named fixed-schedule task which must match input exactly.

### Modified Capabilities

- `two-pass-scheduling`: Pass 2 planning context includes runtime current datetime and a strict lower-bound datetime (+1 hour) with unambiguous instruction that scheduling before or equal to the lower bound is not allowed.
- `assertions`: Integration assertion set includes strict datetime ordering checks and explicit fixed-schedule exception equality check.

## Impact

- Prevents past-date scheduling regressions from LLM output.
- Increases integration-test coverage for real-time scheduling correctness.
- Clarifies boundary behavior for edge cases: strict `>` comparison, exact-match exception, and single runtime timezone authority.
- Explicitly required: unit-test regression is NOT allowed for this change.
- Out of scope: changing task generation logic, changing scheduling algorithm heuristics, and changing inbox task content beyond the named exception rule.

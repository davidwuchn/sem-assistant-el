## 1. Remove brittle title-based scheduling exceptions

- [x] 1.1 Locate and remove Pass 2 title-specific fixed-schedule preservation logic.
- [x] 1.2 Add generic classification of tasks into pre-existing scheduled, pre-existing unscheduled, and newly generated.
- [x] 1.3 Ensure pre-existing scheduled TODOs are preserved with exact original timestamps.
- [x] 1.4 Ensure pre-existing unscheduled TODOs remain unscheduled after Pass 2.

## 2. Strengthen Pass 2 planning inputs and policy

- [x] 2.1 Extend Pass 2 context serialization to include priority when present.
- [x] 2.2 Include occupied-window context derived from pre-existing scheduled TODOs.
- [x] 2.3 Update Pass 2 prompt text to enforce default no-overlap behavior with explicit high-priority exceptions.
- [x] 2.4 Ensure overlap exception handling never mutates preserved pre-existing schedules.

## 3. Align scheduling behavior with updated constraints

- [x] 3.1 Enforce runtime lower-bound checks for newly scheduled tasks while preserving pre-existing schedules unchanged.
- [x] 3.2 Ensure scheduling decisions are based on task state and priority signals, not task title matching.
- [x] 3.3 Add/adjust validation checks so illegal overlaps are detected unless an explicit exception applies.

## 4. Add integration fixtures for pre-existing tasks coverage

- [x] 4.1 Add or update the pre-existing `tasks.org` fixture loaded through the existing WebDAV-style integration path.
- [x] 4.2 Ensure fixture shape meets minimum requirements: 5+ TODOs, 3+ scheduled entries, 1+ unscheduled entry, 1+ priority entry, and mixed tags.
- [x] 4.3 Include occupied daytime windows in fixture schedules to exercise overlap avoidance behavior.

## 5. Expand integration assertions and diagnostics

- [x] 5.1 Add immutability assertions verifying pre-existing TODOs are not mutated, removed, reordered, or re-timestamped.
- [x] 5.2 Add assertions verifying pre-existing unscheduled TODOs remain unscheduled.
- [x] 5.3 Add overlap-policy assertions verifying new tasks avoid pre-existing occupied windows except approved exceptions.
- [x] 5.4 Ensure assertion failures report task-level diagnostics with offending task details.

## 6. Verify and regressions-check the change

- [x] 6.1 Update relevant ERT tests for Pass 2 context, schedule preservation, and overlap policy behavior.
- [x] 6.2 Run `eask test ert app/elisp/tests/sem-test-runner.el` and fix failures.
- [x] 6.3 Run `sh dev/elisplint.sh` on modified elisp files and fix unmatched delimiter issues.
- [x] 6.4 Confirm spec acceptance criteria are satisfied by test evidence and integration assertion outputs.

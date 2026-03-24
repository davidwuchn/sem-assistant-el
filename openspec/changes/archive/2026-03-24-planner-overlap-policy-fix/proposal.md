## Why

The planner currently relies on a hardcoded title exception and weak overlap guidance, which causes fragile behavior and frequent same-slot scheduling. This blocks reliable planning because pre-existing schedules are not treated as a general rule and priority context is not fully available to Pass 2.
Current integration coverage also does not prove behavior when a non-empty pre-existing `tasks.org` is present, so regressions can silently mutate existing TODOs or ignore existing schedule context.

## What Changes

- Remove title-specific fixed-schedule behavior and replace it with a generic rule: any task that already has a pre-existing schedule keeps that schedule unchanged in Pass 2.
- Expand Pass 2 task context sent to the LLM to include priority when present, in addition to ID, tag, and schedule state.
- Strengthen Pass 2 prompt policy so overlap avoidance is the default expectation, with overlap allowed only as an exception case.
- Define explicit exception policy for overlap: pre-existing scheduled tasks remain as-is, and high-priority tasks may overlap when needed.
- Add integration coverage with a pre-existing `tasks.org` fixture loaded through the same WebDAV-style path used by the integration workflow.
- Define required pre-existing `tasks.org` fixture shape for integration:
  - minimum 5 TODO entries total;
  - minimum 3 entries with `SCHEDULED` time ranges that intentionally occupy common daytime windows;
  - minimum 1 unscheduled entry (no `SCHEDULED`) to verify it is not auto-mutated;
  - minimum 1 `PRIORITY` entry to validate priority context handling;
  - mixed tags (`work`, `routine`, and at least one additional allowed tag) to validate anonymized schedule context quality.
- Add explicit assertions that pre-existing TODO entries are not mutated, removed, reordered, or re-timestamped by Pass 2.
- Add explicit assertions that existing TODO schedule context is considered during planning decisions for newly generated tasks.
- Edge cases covered: mixed scheduled/unscheduled pre-existing TODOs, pre-existing high-priority TODOs, and batches where all new tasks could collide with pre-existing occupied slots.
- Define acceptance criteria for this change:
  - no hardcoded title-based schedule exception remains;
  - all pre-existing scheduled TODOs keep exact original timestamps after a full run;
  - all pre-existing unscheduled TODOs remain unscheduled after a full run;
  - pre-existing TODO count and ordering remain byte-stable except for expected append of newly generated tasks;
  - newly generated tasks avoid overlap with pre-existing occupied windows by default;
  - overlap with pre-existing windows is accepted only for explicit exceptions (pre-existing preserved schedule and high-priority urgency policy);
  - Pass 2 planning context includes priority when present for new tasks;
  - integration assertions fail with task-level diagnostics when any invariant above is violated.
- Out of scope: changing Pass 1 generation format, introducing calendar integrations, introducing deterministic slot-packing algorithms, and redefining how legacy pre-existing TODO metadata is authored.

## Capabilities

### New Capabilities

- `planner-overlap-exception-policy`: Pass 2 applies a default no-overlap preference while allowing overlap only for preserved pre-existing schedules and high-priority exception cases.
- `planner-preexisting-tasks-regression-coverage`: Integration workflow validates planner behavior when a pre-existing `tasks.org` is present via WebDAV-style setup.

### Modified Capabilities

- `two-pass-scheduling`: Pass 2 preserves all pre-existing schedules generically (not by title), receives priority in anonymized planning input, and uses stronger overlap-avoidance instructions.
- `assertions`: Integration assertions include invariants for pre-existing TODO immutability and checks that new scheduling decisions respect existing occupied windows except allowed exceptions.

## Impact

Planner behavior becomes predictable across tasks and batches, removes brittle title hardcoding, and reduces unnecessary overlap while retaining controlled exceptions for pre-existing schedules and priority-driven urgency.
Regression risk drops because integration now validates pre-existing `tasks.org` lifecycle and protects against accidental mutation of existing TODOs while still enforcing planning quality for new tasks.

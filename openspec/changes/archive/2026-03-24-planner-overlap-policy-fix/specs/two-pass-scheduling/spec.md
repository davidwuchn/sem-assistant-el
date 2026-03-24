## ADDED Requirements

### Requirement: Pass 2 planning context includes priority and schedule-state signals
Pass 2 planning context MUST include per-task identifiers and schedule metadata needed for overlap policy decisions. For each task, context MUST include ID, tags, schedule state, and priority when present. Context MUST also include occupied-window information derived from pre-existing scheduled TODOs.

#### Scenario: Priority is present in Pass 2 context when available
- **WHEN** a task has a priority value
- **THEN** Pass 2 context MUST include that priority for the task

#### Scenario: Occupied windows are represented in planning context
- **WHEN** pre-existing TODOs include scheduled ranges
- **THEN** Pass 2 context MUST include occupied-window data representing those ranges

### Requirement: Pass 2 prompt encodes default no-overlap policy
Pass 2 prompt instructions MUST state that overlap with pre-existing occupied windows is disallowed by default and allowed only for explicit exceptions.

#### Scenario: Prompt communicates exception boundaries
- **WHEN** Pass 2 prompt is assembled
- **THEN** it MUST instruct default no-overlap behavior
- **AND** it MUST allow overlap only for approved exception policy cases

## MODIFIED Requirements

### Requirement: Pass 2 may override Pass 1 timing
The provisional SCHEDULED from Pass 1 SHALL be treated as a hint only for newly generated tasks. Pass 2 MAY override provisional timing with different timing based on rules and existing schedule, and Pass 2 MUST enforce the runtime minimum start bound provided in planning context (`runtime_min_start = runtime_now + 1 hour`) for newly scheduled tasks. Pass 2 MUST preserve all pre-existing scheduled TODO timestamps exactly as authored and MUST keep pre-existing unscheduled TODOs unscheduled.

#### Scenario: Pass 2 overrides Pass 1 timing for newly generated tasks
- **WHEN** Pass 2 determines a better schedule based on rules
- **THEN** the final newly generated task entry MAY have different SCHEDULED than Pass 1 provisional

#### Scenario: Pass 2 enforces strict runtime lower bound for newly scheduled tasks
- **WHEN** Pass 2 schedules a newly generated task
- **THEN** the selected timestamp MUST be strictly greater than `runtime_min_start`
- **AND** Pass 2 MUST NOT output a timestamp less than or equal to `runtime_min_start`

#### Scenario: Pass 2 preserves all pre-existing scheduled timestamps generically
- **WHEN** Pass 2 processes any pre-existing TODO that already has a SCHEDULED timestamp
- **THEN** Pass 2 MUST preserve the exact original timestamp
- **AND** preservation MUST NOT depend on task title matching

#### Scenario: Pass 2 keeps pre-existing unscheduled TODOs unscheduled
- **WHEN** Pass 2 processes any pre-existing TODO without a SCHEDULED timestamp
- **THEN** Pass 2 MUST NOT add a new SCHEDULED timestamp to that TODO

## MODIFIED Requirements

### Requirement: Pass 2 may override Pass 1 timing
The provisional SCHEDULED from Pass 1 SHALL be treated as a hint only. Pass 2 MAY override it
with different timing based on rules and existing schedule, and Pass 2 MUST enforce the runtime
minimum start bound provided in planning context (`runtime_min_start = runtime_now + 1 hour`).

#### Scenario: Pass 2 overrides Pass 1 timing
- **WHEN** Pass 2 determines a better schedule based on rules
- **THEN** the final task entry MAY have different SCHEDULED than Pass 1 provisional

#### Scenario: Pass 2 enforces strict runtime lower bound
- **WHEN** Pass 2 schedules a task that is not the fixed-schedule exception
- **THEN** the selected timestamp MUST be strictly greater than `runtime_min_start`
- **AND** Pass 2 MUST NOT output a timestamp less than or equal to `runtime_min_start`

#### Scenario: Pass 2 preserves fixed-schedule exception
- **WHEN** Pass 2 processes the task titled `Process quarterly financial reports`
- **THEN** Pass 2 MUST preserve the exact scheduled timestamp defined by the inbox task input

## MODIFIED Requirements

### Requirement: Pass 2 may override Pass 1 timing
The provisional SCHEDULED from Pass 1 SHALL be treated as a hint only for newly generated tasks. Pass 2 MAY override provisional timing with different timing based on rules and existing schedule, and Pass 2 MUST enforce the runtime minimum start bound provided in planning context (`runtime_min_start = runtime_now + 1 hour`) for newly scheduled tasks. `runtime_now` and `runtime_min_start` MUST be computed using `CLIENT_TIMEZONE`. Pass 2 MUST preserve all pre-existing scheduled TODO timestamps exactly as authored and MUST keep pre-existing unscheduled TODOs unscheduled. Tasks arriving from Pass 1 without SCHEDULED MUST remain valid planner inputs and MAY be scheduled or left unscheduled by Pass 2 according to planning rules.

#### Scenario: Pass 2 overrides Pass 1 timing for newly generated tasks
- **WHEN** Pass 2 determines a better schedule based on rules
- **THEN** the final newly generated task entry MAY have different SCHEDULED than Pass 1 provisional

#### Scenario: Pass 2 enforces strict runtime lower bound for newly scheduled tasks
- **WHEN** Pass 2 schedules a newly generated task
- **THEN** the selected timestamp MUST be strictly greater than `runtime_min_start`
- **AND** Pass 2 MUST NOT output a timestamp less than or equal to `runtime_min_start`

#### Scenario: Runtime bounds derived from client timezone now
- **WHEN** planning context computes `runtime_now` and `runtime_min_start`
- **THEN** both values are derived from current time in `CLIENT_TIMEZONE`
- **AND** bounds are not derived from UTC-forced or host-default timezone semantics

#### Scenario: Pass 2 preserves all pre-existing scheduled timestamps generically
- **WHEN** Pass 2 processes any pre-existing TODO that already has a SCHEDULED timestamp
- **THEN** Pass 2 MUST preserve the exact original timestamp
- **AND** preservation MUST NOT depend on task title matching

#### Scenario: Pass 2 keeps pre-existing unscheduled TODOs unscheduled
- **WHEN** Pass 2 processes any pre-existing TODO without a SCHEDULED timestamp
- **THEN** Pass 2 MUST NOT add a new SCHEDULED timestamp to that TODO

#### Scenario: Pass 2 handles unscheduled Pass 1 tasks
- **WHEN** Pass 2 receives newly generated tasks with no provisional SCHEDULED
- **THEN** those tasks are still considered valid inputs for planning decisions

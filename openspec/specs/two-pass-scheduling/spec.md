## Purpose

This capability defines the two-pass scheduling architecture where Pass 1 generates provisional time ranges and Pass 2 re-schedules tasks into actual free time using rules and anonymized schedule context.

## ADDED Requirements

### Requirement: Two-pass execution order
The system SHALL execute scheduling in two passes: Pass 1 generates provisional task entries with guessed time ranges, then Pass 2 reads all temp tasks plus rules plus anonymized existing schedule and re-schedules into actual free time.

#### Scenario: Pass 1 runs before Pass 2
- **WHEN** a batch of inbox items is processed
- **THEN** Pass 1 completes for all items before Pass 2 begins

### Requirement: Pass 1 generates SCHEDULED time range
Pass 1 SHALL generate provisional task entries with `SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>` format indicating a time range hint.

#### Scenario: Pass 1 output includes time range
- **WHEN** Pass 1 generates a task entry
- **THEN** the SCHEDULED field uses format `SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>`

### Requirement: Pass 2 outputs scheduling decisions in simple format
Pass 2 SHALL output scheduling decisions in a simple line-based format, one line per task:
```
ID: <uuid> | SCHEDULED: <timestamp>
ID: <uuid> | (unscheduled)
```

#### Scenario: Pass 2 uses simple scheduling format
- **WHEN** Pass 2 generates scheduling decisions
- **THEN** each decision is on its own line
- **AND** format is `ID: <uuid> | SCHEDULED: <timestamp>` or `ID: <uuid> | (unscheduled)`
- **AND** task bodies are NOT included in Pass 2 output

### Requirement: Merge step combines Pass 2 decisions with Pass 1 task bodies
After Pass 2 returns scheduling decisions, a merge step SHALL combine the decisions with full task bodies from the Pass 1 temp file.

#### Scenario: Merge combines scheduling with task bodies
- **WHEN** Pass 2 returns scheduling decisions
- **THEN** each decision is matched to its task in the temp file by ID
- **AND** the SCHEDULED from Pass 2 is injected into the matching task
- **AND** the full task body from Pass 1 is preserved

### Requirement: Scheduling decision matched to task by ID
The merge step SHALL match Pass 2 scheduling decisions to Pass 1 tasks by matching the `:ID:` property.

#### Scenario: ID matching for merge
- **WHEN** a Pass 2 decision contains `ID: abc-123`
- **THEN** the task in temp file with `:ID: abc-123` receives the scheduling
- **AND** tasks with non-matching IDs are not modified by that decision

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

### Requirement: Pass 2 retry with exponential backoff
Pass 2 SHALL retry up to 3 times with exponential backoff on LLM failure. Default delay base is 1 second.

#### Scenario: LLM failure triggers retry
- **WHEN** Pass 2 LLM call fails
- **THEN** the system retries with exponential backoff: 1s, 2s, 4s

#### Scenario: All retries exhausted
- **WHEN** Pass 2 LLM call fails 3 times
- **THEN** no more retries are attempted

### Requirement: Fallback to Pass 1 timing on exhausted retries
When all 3 Pass 2 retries are exhausted, tasks SHALL be written to tasks.org with the provisional (Pass 1) timing.

#### Scenario: Fallback writes Pass 1 timing
- **WHEN** Pass 2 retries are exhausted
- **THEN** tasks are written with Pass 1 provisional SCHEDULED times
- **AND** an error is logged with `sem-core-log-error` module `planner`

### Requirement: Default planning prompt
Pass 2 SHALL use the default planning prompt "schedule tasks" unless overridden.

#### Scenario: Default prompt used
- **WHEN** Pass 2 runs without a custom prompt
- **THEN** the prompt "schedule tasks" is used

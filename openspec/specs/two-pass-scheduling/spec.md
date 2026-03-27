## Purpose

This capability defines the two-pass scheduling architecture where Pass 1 generates provisional time ranges and Pass 2 re-schedules tasks into actual free time using rules and anonymized schedule context.

## ADDED Requirements

### Requirement: Two-pass execution order
The system SHALL execute scheduling in two passes: Pass 1 generates provisional task entries with guessed time ranges, then Pass 2 reads all temp tasks plus rules plus anonymized existing schedule and re-schedules into actual free time.

#### Scenario: Pass 1 runs before Pass 2
- **WHEN** a batch of inbox items is processed
- **THEN** Pass 1 completes for all items before Pass 2 begins

### Requirement: Pass 1 generates SCHEDULED time range
Pass 1 SHALL generate provisional task entries with `SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>` format when schedule intent can be inferred with sufficient confidence. Pass 1 SHALL permit unscheduled task output when confidence is low or timing intent is ambiguous.

#### Scenario: Pass 1 output includes time range
- **WHEN** Pass 1 generates a task entry
- **THEN** the SCHEDULED field uses format `SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>`

#### Scenario: Pass 1 leaves ambiguous task unscheduled
- **WHEN** Pass 1 receives input with ambiguous or conflicting timing cues
- **THEN** it may return a valid task entry without `SCHEDULED`

### Requirement: Pass 2 outputs scheduling decisions in simple format
Pass 2 SHALL output scheduling decisions in a simple line-based format, one line per task:
```
ID: <uuid> | SCHEDULED: <timestamp>
ID: <uuid> | (unscheduled)
```
Decision parsing MUST be deterministic and line-scoped: each decision line SHALL map exactly one task ID to exactly one scheduling outcome, and parsing MUST NOT scan neighboring lines to infer or merge outcomes.

#### Scenario: Pass 2 uses simple scheduling format
- **WHEN** Pass 2 generates scheduling decisions
- **THEN** each decision is on its own line
- **AND** format is `ID: <uuid> | SCHEDULED: <timestamp>` or `ID: <uuid> | (unscheduled)`
- **AND** task bodies are NOT included in Pass 2 output

#### Scenario: Mixed scheduled and unscheduled lines are parsed independently
- **WHEN** Pass 2 output contains adjacent `SCHEDULED` and `(unscheduled)` decision lines for different task IDs
- **THEN** each line maps only to the task ID present on that same line
- **AND** no scheduling outcome is inherited from or associated with another line

### Requirement: Merge step combines Pass 2 decisions with Pass 1 task bodies
After Pass 2 returns scheduling decisions, a merge step SHALL combine the decisions with full task bodies from the Pass 1 temp file. Before append, the planner SHALL validate that `tasks.org` still matches the base file version used to build Pass 2 context. On version mismatch, the planner SHALL discard the stale merge result, rebuild planning context from current file state, and rerun Pass 2 within a bounded retry budget.

#### Scenario: Merge combines scheduling with task bodies after version validation
- **WHEN** Pass 2 returns scheduling decisions and the base file version is unchanged
- **THEN** each decision is matched to its task in the temp file by ID
- **AND** the SCHEDULED from Pass 2 is injected into the matching task
- **AND** the full task body from Pass 1 is preserved for append

#### Scenario: Version mismatch triggers replan before merge append
- **WHEN** pre-append validation detects that `tasks.org` changed since Pass 2 input generation
- **THEN** the stale merge output is not appended
- **AND** Pass 2 planning is rerun from fresh file state

### Requirement: Scheduling decision matched to task by ID
The merge step SHALL match Pass 2 scheduling decisions to Pass 1 tasks by matching the `:ID:` property.

#### Scenario: ID matching for merge
- **WHEN** a Pass 2 decision contains `ID: abc-123`
- **THEN** the task in temp file with `:ID: abc-123` receives the scheduling
- **AND** tasks with non-matching IDs are not modified by that decision

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

### Requirement: Pass 2 may override Pass 1 timing
The provisional SCHEDULED from Pass 1 SHALL be treated as a hint only for newly generated tasks. Pass 2 MAY override provisional timing with different timing based on rules and existing schedule, and Pass 2 MUST enforce the runtime minimum start bound provided in planning context (`runtime_min_start = runtime_now + 1 hour`) for newly scheduled tasks. Pass 2 MUST preserve all pre-existing scheduled TODO timestamps exactly as authored and MUST keep pre-existing unscheduled TODOs unscheduled. Tasks arriving from Pass 1 without SCHEDULED MUST remain valid planner inputs and MAY be scheduled or left unscheduled by Pass 2 according to planning rules.

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

#### Scenario: Pass 2 handles unscheduled Pass 1 tasks
- **WHEN** Pass 2 receives newly generated tasks with no provisional SCHEDULED
- **THEN** those tasks are still considered valid inputs for planning decisions

### Requirement: Pass 2 retry with exponential backoff
Pass 2 SHALL retry up to 3 times with exponential backoff on LLM failure. Default delay base is 1 second.

#### Scenario: LLM failure triggers retry
- **WHEN** Pass 2 LLM call fails
- **THEN** the system retries with exponential backoff: 1s, 2s, 4s

#### Scenario: All retries exhausted
- **WHEN** Pass 2 LLM call fails 3 times
- **THEN** no more retries are attempted

### Requirement: Fallback to Pass 1 timing on exhausted retries
When planner retries are exhausted due to repeated file-version conflicts, tasks SHALL NOT be appended using stale Pass 1 or stale Pass 2 output. The planner SHALL return an explicit non-success conflict outcome and SHALL log the failure deterministically.

#### Scenario: Conflict retries exhausted produce explicit non-success
- **WHEN** file-version conflicts persist until retry budget is exhausted
- **THEN** no stale scheduling output is appended to `tasks.org`
- **AND** the planner reports a non-success conflict outcome with error logging

### Requirement: Pass 2 uses structured planning prompt
Pass 2 SHALL build a structured planning prompt that includes runtime bounds, user rules, existing schedule context, occupied windows, and anonymized task metadata.

#### Scenario: Structured prompt used
- **WHEN** Pass 2 runs
- **THEN** the prompt includes runtime bounds and scheduling rules
- **AND** the prompt requests one-line scheduling decisions per task ID

## MODIFIED Requirements

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

### Requirement: Fallback to Pass 1 timing on exhausted retries
When planner retries are exhausted due to repeated file-version conflicts, tasks SHALL NOT be appended using stale Pass 1 or stale Pass 2 output. The planner SHALL return an explicit non-success conflict outcome and SHALL log the failure deterministically.

#### Scenario: Conflict retries exhausted produce explicit non-success
- **WHEN** file-version conflicts persist until retry budget is exhausted
- **THEN** no stale scheduling output is appended to `tasks.org`
- **AND** the planner reports a non-success conflict outcome with error logging

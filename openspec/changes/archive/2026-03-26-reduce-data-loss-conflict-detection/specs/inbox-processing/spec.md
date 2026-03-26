## MODIFIED Requirements

### Requirement: Inbox processing runs every 30 minutes
The system SHALL execute inbox processing every 30 minutes via cron. Each run SHALL route task headlines through Pass 1 into `/tmp/data/tasks-tmp-{batch-id}.org` and then invoke conflict-aware Pass 2 planning before append to `/data/tasks.org`. If append preconditions fail due to concurrent file updates, planner outcomes SHALL be retry or explicit non-success, never silent overwrite.

#### Scenario: Scheduled inbox processing executes with conflict-aware append
- **WHEN** the cron schedule triggers at 30-minute intervals
- **THEN** `sem-core-process-inbox` runs and processes unprocessed headlines
- **AND** final append uses conflict-aware planner checks before writing to `/data/tasks.org`

#### Scenario: Contention produces explicit planner outcome
- **WHEN** concurrent updates change `tasks.org` during planner merge window
- **THEN** planner records retry or non-success outcome
- **AND** no silent last-writer-wins overwrite occurs

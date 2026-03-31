## MODIFIED Requirements

### Requirement: Inbox processing runs every 30 minutes
The system SHALL execute inbox processing every 30 minutes via cron evaluated in `CLIENT_TIMEZONE`. Each run SHALL route task headlines through Pass 1 into `/tmp/data/tasks-tmp-{batch-id}.org` and then invoke conflict-aware Pass 2 planning before append to `/data/tasks.org`. If append preconditions fail due to concurrent file updates, planner outcomes SHALL be retry or explicit non-success, never silent overwrite.

#### Scenario: Scheduled inbox processing executes with conflict-aware append
- **WHEN** the cron schedule triggers at 30-minute intervals in `CLIENT_TIMEZONE`
- **THEN** `sem-core-process-inbox` runs and processes unprocessed headlines
- **AND** final append uses conflict-aware planner checks before writing to `/data/tasks.org`

### Requirement: Pass 1 runtime context uses client timezone semantics
Pass 1 runtime datetime context supplied to the task LLM SHALL be represented in `CLIENT_TIMEZONE`. Prompt wording and formatting MUST NOT imply UTC semantics when `CLIENT_TIMEZONE` is non-UTC.

#### Scenario: Prompt runtime datetime uses configured timezone
- **WHEN** Pass 1 prompt context is generated
- **THEN** runtime datetime values are expressed in `CLIENT_TIMEZONE`

#### Scenario: Prompt wording avoids false UTC implication
- **WHEN** `CLIENT_TIMEZONE` is not UTC
- **THEN** prompt labels and text do not describe runtime context as UTC

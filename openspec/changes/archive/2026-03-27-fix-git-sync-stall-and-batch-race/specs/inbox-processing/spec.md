## MODIFIED Requirements

### Requirement: Inbox processing runs every 30 minutes
The system SHALL execute inbox processing every 30 minutes via cron. Each run SHALL route task headlines through Pass 1 into `/tmp/data/tasks-tmp-{batch-id}.org` and then invoke conflict-aware Pass 2 planning before append to `/data/tasks.org`. If append preconditions fail due to concurrent file updates, planner outcomes SHALL be retry or explicit non-success, never silent overwrite.

#### Scenario: Scheduled inbox processing executes with conflict-aware append
- **WHEN** the cron schedule triggers at 30-minute intervals
- **THEN** `sem-core-process-inbox` runs and processes unprocessed headlines
- **AND** final append uses conflict-aware planner checks before writing to `/data/tasks.org`

#### Scenario: Unprocessed headlines are processed
- **WHEN** `/data/inbox-mobile.org` contains headlines not yet in the cursor file
- **THEN** each unprocessed headline is sent through the LLM pipeline

#### Scenario: Pass 1 output is written to batch temp file
- **WHEN** the LLM returns valid structured Org output for a task headline
- **THEN** the output is appended to `/tmp/data/tasks-tmp-{batch-id}.org`

#### Scenario: Contention produces explicit planner outcome
- **WHEN** concurrent updates change `tasks.org` during planner merge window
- **THEN** planner records retry or non-success outcome
- **AND** no silent last-writer-wins overwrite occurs

### Requirement: sem-core--batch-id incremented at start of each cron-triggered inbox processing
At the start of each cron-triggered `sem-core-process-inbox`, `sem-core--batch-id` SHALL be incremented.

#### Scenario: Batch ID increments on new cron run
- **WHEN** `sem-core-process-inbox` is called by cron
- **THEN** `sem-core--batch-id` is incremented

### Requirement: sem-core--pending-callbacks tracks routed items
`sem-core--pending-callbacks` SHALL be tracked for each routed inbox item. The counter SHALL be incremented when a callback is registered and decremented when it completes.

#### Scenario: Pending count tracked per item
- **WHEN** an inbox item is routed to LLM
- **THEN** `sem-core--pending-callbacks` is incremented

### Requirement: Pass 1 results written to batch temp file
During inbox processing, Pass 1 results SHALL be written to the batch temp file `/tmp/data/tasks-tmp-{batch-id}.org` instead of tasks.org.

#### Scenario: Results written to temp file
- **WHEN** Pass 1 generates task entries
- **THEN** they are written to `/tmp/data/tasks-tmp-{batch-id}.org`

### Requirement: Planning step called when pending count reaches zero
`sem-planner-run-planning-step` SHALL be called when `sem-core--pending-callbacks` reaches 0.

#### Scenario: Planning step called at barrier
- **WHEN** the last pending callback completes
- **THEN** `sem-planner-run-planning-step` is invoked

### Requirement: rules.org read at start of each batch
`rules.org` SHALL be read fresh at the start of each `sem-core-process-inbox` call via `sem-rules-read`.

#### Scenario: Rules read at batch start
- **WHEN** `sem-core-process-inbox` starts
- **THEN** `sem-rules-read` is called to get current rules

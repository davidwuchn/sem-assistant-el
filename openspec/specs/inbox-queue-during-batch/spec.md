## Purpose

This capability defines how concurrent inbox items are queued to the current batch when a new cron run fires during the planning phase.

## ADDED Requirements

### Requirement: Items queue to current batch during planning
If a new cron run fires while a batch is in the planning phase, new inbox items SHALL be added to the current batch with the same `batch-id`.

#### Scenario: Items queued during planning phase
- **WHEN** cron fires while Pass 2 is running
- **THEN** new inbox items are queued to the current batch
- **AND** `batch-id` is NOT incremented

### Requirement: Pending count grows for queued items
Each new item added to the current batch SHALL increment `sem-core--pending-callbacks`.

#### Scenario: Queued item increments pending count
- **WHEN** a new item is queued to the current batch
- **THEN** `sem-core--pending-callbacks` is incremented

### Requirement: Queued items appended to same temp file
New items SHALL be appended to the same temp file (`/tmp/data/tasks-tmp-{batch-id}.org`) as the original batch items.

#### Scenario: Queued items go to same temp file
- **WHEN** a new item is queued
- **THEN** it is written to the same temp file as other items in the batch

### Requirement: Single planning step at a time
Only one planning step SHALL run at a time. The implicit lock is maintained by not incrementing `batch-id` during planning.

#### Scenario: Only one planning step executes
- **WHEN** a planning step is running
- **THEN** new cron runs queue items to the current batch instead of starting a new planning step

## Purpose

This capability defines the batch temp file mechanism for storing provisional task entries during Pass 1.

## ADDED Requirements

### Requirement: Temp file naming convention
During Pass 1, each task in the batch SHALL be written to a temp file named `/tmp/data/tasks-tmp-{batch-id}.org` where `batch-id` is the current batch identifier.

#### Scenario: Temp file uses batch ID in name
- **WHEN** batch ID is 42
- **THEN** temp file path is `/tmp/data/tasks-tmp-42.org`

### Requirement: Temp file uses same org-mode format as tasks.org
The temp file SHALL use the same org-mode TODO format as `tasks.org` for task entries.

#### Scenario: Temp file format matches tasks.org
- **WHEN** a task entry is written to temp file
- **THEN** it uses the same Org format as tasks.org

### Requirement: Batch ID is monotonically increasing counter
The batch ID SHALL be a monotonically increasing counter stored in `sem-core--batch-id`. Each new cron-triggered batch SHALL increment this counter.

#### Scenario: Batch ID increments on new cron run
- **WHEN** a new cron-triggered inbox processing starts
- **THEN** `sem-core--batch-id` is incremented

### Requirement: Pass 1 writes go to temp file not tasks.org
During Pass 1, writes SHALL go to the batch temp file instead of `tasks.org`.

#### Scenario: Pass 1 writes to temp file
- **WHEN** Pass 1 generates a task entry
- **THEN** the entry is written to `/tmp/data/tasks-tmp-{batch-id}.org`
- **AND** `tasks.org` is NOT written to during Pass 1

### Requirement: Batch temp file deleted after retries exhausted
When all Pass 2 retries are exhausted and tasks are written with Pass 1 timing, the batch temp file SHALL be deleted.

#### Scenario: Temp file deleted on fallback
- **WHEN** Pass 2 retries are exhausted
- **THEN** the batch temp file `/tmp/data/tasks-tmp-{batch-id}.org` is deleted

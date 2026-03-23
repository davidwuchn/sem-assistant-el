## Purpose

This capability defines the atomic append mechanism for writing merged planned tasks to tasks.org after Pass 2 completes and merge step finishes.

## ADDED Requirements

### Requirement: Append merged tasks to tasks.org
New tasks from a batch SHALL be appended to the end of `tasks.org`, never replacing existing content.

#### Scenario: Tasks appended to end
- **WHEN** Pass 2 completes and merge step finishes
- **THEN** the merged tasks are appended to the end of tasks.org
- **AND** existing tasks in tasks.org are preserved unchanged

### Requirement: Re-read tasks.org before append
Before appending, the system SHALL re-read `tasks.org` to get the latest state in case it was modified via WebDAV concurrent with batch processing.

#### Scenario: Re-read before append
- **WHEN** Pass 2 completes and tasks.org will be updated
- **THEN** the system re-reads tasks.org to find the current end offset

### Requirement: Write to temp file then rename
The merged task entries SHALL be written to a new temp file, then `rename-file` SHALL be used to atomically update `tasks.org`.

#### Scenario: Atomic rename used
- **WHEN** merged tasks are ready to be appended
- **THEN** they are written to a new temp file with `\n` separator
- **AND** `rename-file` is used to atomically update tasks.org

### Requirement: Append is atomic
The `rename-file` operation SHALL be atomic so readers never see partial writes.

#### Scenario: Append is atomic
- **WHEN** `rename-file` is used to update tasks.org
- **THEN** the operation is atomic from the reader's perspective

### Requirement: Handles concurrent WebDAV edits
Re-reading before the append SHALL handle concurrent WebDAV edits to tasks.org.

#### Scenario: Concurrent edit preserved
- **WHEN** tasks.org was edited via WebDAV while batch was processing
- **THEN** the re-read captures those changes
- **AND** the atomic append includes those changes in the final file

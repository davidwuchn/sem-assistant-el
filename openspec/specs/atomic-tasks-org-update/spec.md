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
Before appending, the system SHALL re-read `tasks.org` and SHALL compute a deterministic content hash representing the latest file version. The append SHALL proceed only if this pre-append hash matches the base hash captured before Pass 2 input generation.

#### Scenario: Re-read and hash verification before append
- **WHEN** Pass 2 completes and tasks.org will be updated
- **THEN** the system re-reads `tasks.org` and computes the current content hash
- **AND** append proceeds only when the hash matches the planning base hash

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
Concurrent WebDAV edits SHALL be handled by stale-write detection, not blind append. On hash mismatch, the system SHALL abort the stale append attempt and trigger bounded replanning against the latest file version.

#### Scenario: Concurrent edit causes stale append rejection
- **WHEN** tasks.org was edited via WebDAV while batch was processing
- **THEN** the stale append attempt is rejected on hash mismatch
- **AND** replanning is triggered using the newest file state

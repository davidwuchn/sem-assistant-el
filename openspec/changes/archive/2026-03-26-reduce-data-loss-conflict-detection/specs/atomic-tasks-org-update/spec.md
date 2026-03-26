## MODIFIED Requirements

### Requirement: Re-read tasks.org before append
Before appending, the system SHALL re-read `tasks.org` and SHALL compute a deterministic content hash representing the latest file version. The append SHALL proceed only if this pre-append hash matches the base hash captured before Pass 2 input generation.

#### Scenario: Re-read and hash verification before append
- **WHEN** Pass 2 completes and tasks.org will be updated
- **THEN** the system re-reads `tasks.org` and computes the current content hash
- **AND** append proceeds only when the hash matches the planning base hash

### Requirement: Handles concurrent WebDAV edits
Concurrent WebDAV edits SHALL be handled by stale-write detection, not blind append. On hash mismatch, the system SHALL abort the stale append attempt and trigger bounded replanning against the latest file version.

#### Scenario: Concurrent edit causes stale append rejection
- **WHEN** tasks.org was edited via WebDAV while a batch was processing
- **THEN** the stale append attempt is rejected on hash mismatch
- **AND** replanning is triggered using the newest file state

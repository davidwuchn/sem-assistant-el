## MODIFIED Requirements

### Requirement: Batch temp file deleted after retries exhausted
When Pass 2 planning returns an explicit non-success outcome, the system SHALL preserve generated Pass 1 tasks from `/tmp/data/tasks-tmp-{batch-id}.org` using fallback semantics so tasks are either persisted or explicitly surfaced as failed. Batch temp-file deletion MUST NOT occur before this preservation outcome is finalized.

#### Scenario: Explicit planning non-success preserves generated tasks
- **WHEN** Pass 2 returns an explicit non-success outcome for a batch
- **THEN** generated Pass 1 tasks are preserved for fallback handling
- **AND** task output is not silently dropped by temp-file cleanup

#### Scenario: Temp cleanup runs only after deterministic fallback outcome
- **WHEN** fallback handling has either persisted generated tasks or recorded an explicit failed outcome
- **THEN** temp-file cleanup may proceed for that batch

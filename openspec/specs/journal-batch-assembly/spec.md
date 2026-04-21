## Purpose

This capability defines deterministic batch assembly behavior for `:journal:` inbox entries before any journal file mutation.

## Requirements

### Requirement: Journal entries are prepared as a complete batch before write
The system SHALL collect and transform all `:journal:` headlines selected in the current run before mutating `journal.org`. If any selected headline fails deterministic journal transformation, the system MUST skip journal file mutation for that batch.

#### Scenario: Journal batch prepared before append
- **WHEN** multiple `:journal:` headlines are present in one run
- **THEN** the system builds all per-entry journal fragments first
- **AND** no append to `journal.org` occurs during per-entry transformation

#### Scenario: Transformation failure blocks append
- **WHEN** one selected `:journal:` headline fails transformation in the batch
- **THEN** the system does not append a partial journal payload for that batch

### Requirement: Journal batch appends as one payload and one write operation
After successful preparation, the system SHALL assemble one final append payload for all selected journal entries and perform exactly one append write to `journal.org` for the batch.

#### Scenario: Single append for multi-entry batch
- **WHEN** three `:journal:` headlines are successfully prepared in one run
- **THEN** the final payload contains all three journal entries
- **AND** the system appends the payload to `journal.org` exactly once

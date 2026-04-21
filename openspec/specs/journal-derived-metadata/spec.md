## Purpose

This capability defines deterministic metadata derivation for journal entries routed from inbox processing.

## Requirements

### Requirement: Journal metadata records ingestion timestamp semantics
Each appended journal item SHALL include `INGESTED_AT` set to batch processing time. `INGESTED_AT` MUST represent ingestion time and not inferred event time.

#### Scenario: Ingested-at reflects batch time
- **WHEN** a journal batch is processed
- **THEN** each appended journal item contains an `INGESTED_AT` property from that batch run

### Requirement: Journal metadata preserves non-routing inbox tags
Each appended journal item SHALL include `TAGS_INBOX` containing all user-supplied headline tags except the routing tag `journal`.

#### Scenario: Non-routing tags are preserved
- **WHEN** the inbox headline is tagged `:journal:work:family:`
- **THEN** the journal item contains `:TAGS_INBOX: :work:family:`

### Requirement: Journal metadata does not rewrite captured body text
Derived metadata generation SHALL NOT rewrite, sanitize, or replace the raw journal body text captured from the inbox entry.

#### Scenario: Raw body remains unchanged
- **WHEN** a journal entry body includes punctuation and free-form wording
- **THEN** the appended journal body text matches the captured body text exactly

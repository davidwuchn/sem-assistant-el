# Specification: spec-code-alignment

## Purpose

Define requirements for reconciling OpenSpec artifacts with implemented repository behavior without expanding runtime scope.

## Requirements

### Requirement: OpenSpec artifacts are reconciled with implemented behavior
OpenSpec artifacts SHALL be updated only where they diverge from implemented code behavior, and updates MUST preserve existing intent without adding new runtime requirements.

#### Scenario: Spec deltas are evidence-based
- **WHEN** a spec file is modified under this change
- **THEN** each modification MUST map to behavior that is observable in the current codebase
- **AND** unsupported or speculative requirements MUST NOT be introduced

#### Scenario: Scope remains documentation and specification only
- **WHEN** reconciling spec artifacts with code
- **THEN** the change MUST NOT require runtime feature additions, refactors, or infrastructure behavior changes
- **AND** out-of-scope implementation ideas MUST be documented as non-goals or follow-up work

#### Scenario: Reconciliation map ties edits to repository evidence
- **WHEN** README and capability wording are adjusted under this change
- **THEN** each planned edit MUST map to an observable repository location (for example `README.md`, `docker-compose.yml`, `.env.example`, or `webdav/apache/`)
- **AND** mappings MUST avoid introducing requirements that cannot be verified from the current repository state

#### Scenario: Follow-up notes isolate deferred implementation ideas
- **WHEN** implementation-adjacent ideas are discovered during documentation reconciliation
- **THEN** those ideas MUST be captured as explicit follow-up notes
- **AND** they MUST be marked out of scope for this change

#### Scenario: Existing capability intent is preserved
- **WHEN** mismatched requirement text is corrected
- **THEN** corrections MUST preserve the original capability intent
- **AND** the update MUST clarify mismatches rather than redefine the capability

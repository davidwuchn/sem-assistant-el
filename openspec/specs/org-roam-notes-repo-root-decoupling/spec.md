# Specification: org-roam-notes-repo-root-decoupling

## Purpose

Define explicit separation between org-roam notes root and git repository root responsibilities.

## Requirements

### Requirement: Distinct notes root and repository root are enforced
The system SHALL maintain two explicit path contracts with non-overlapping responsibilities: notes root at `/data/org-roam/org-files/` and repository root at `/data/org-roam`.

#### Scenario: org-roam operations use notes root
- **WHEN** the daemon creates org-roam nodes or rebuilds the org-roam database
- **THEN** it MUST resolve note file paths and scan roots from `/data/org-roam/org-files/`

#### Scenario: git sync operations use repository root
- **WHEN** the daemon initializes git state, checks sync readiness, or runs scheduled sync
- **THEN** it MUST execute repository operations from `/data/org-roam`

#### Scenario: Path responsibilities remain decoupled
- **WHEN** notes-root behavior is changed under `org-files/`
- **THEN** git repository-root behavior remains anchored at `/data/org-roam`
- **AND** notes creation MUST NOT target `/data/org-roam` top-level

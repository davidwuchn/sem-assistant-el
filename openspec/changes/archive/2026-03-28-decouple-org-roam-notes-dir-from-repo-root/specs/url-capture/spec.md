## MODIFIED Requirements

### Requirement: LLM output validated before saving
The system SHALL validate LLM output before writing to disk. Validation SHALL check for presence of `:PROPERTIES:`, `:ID:`, and `#+title:`. Invalid output SHALL be sent to `/data/errors.org`. Valid output SHALL be saved under the notes root `/data/org-roam/org-files/` and SHALL NOT be written to `/data/org-roam` top-level.

#### Scenario: Valid output passes validation
- **WHEN** LLM output contains `:PROPERTIES:`, `:ID:`, and `#+title:`
- **THEN** the output is saved to `/data/org-roam/org-files/`
- **AND** no new node file is written directly under `/data/org-roam`

#### Scenario: Missing :PROPERTIES: fails validation
- **WHEN** LLM output lacks `:PROPERTIES:` block
- **THEN** the output is sent to `/data/errors.org` and `nil` is returned

#### Scenario: Missing :ID: fails validation
- **WHEN** LLM output lacks `:ID:` in properties
- **THEN** the output is sent to `/data/errors.org` and `nil` is returned

#### Scenario: Missing #+title: fails validation
- **WHEN** LLM output lacks `#+title:` line
- **THEN** the output is sent to `/data/errors.org` and `nil` is returned

### Requirement: org-roam directory hardcoded
The system SHALL configure org-roam note operations to use `/data/org-roam/org-files/` as the canonical notes directory. This notes-root contract SHALL be set in startup configuration and SHALL be used by URL-capture output paths.

#### Scenario: org-roam uses canonical notes root
- **WHEN** the daemon starts
- **THEN** org-roam note destination resolves to `/data/org-roam/org-files/`

#### Scenario: URL-capture writes only under notes root
- **WHEN** URL-capture saves a generated node
- **THEN** the saved filepath is under `/data/org-roam/org-files/`
- **AND** URL-capture does not write new nodes directly under `/data/org-roam`

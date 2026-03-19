## ADDED Requirements

### Requirement: Test data directory is isolated from production
The system SHALL use a separate `./test-data/` directory for ephemeral test data.

#### Scenario: Test data directory is created at start
- **WHEN** the test script starts
- **THEN** if `./test-data/` exists, it MUST be deleted entirely
- **AND** then recreated with subdirectories: `test-data/org-roam`, `test-data/elfeed`, `test-data/morning-read`, `test-data/prompts`

#### Scenario: Test data is git-ignored
- **WHEN** the test script runs
- **THEN** the `./test-data/` directory MUST be git-ignored

#### Scenario: Test data is separate from production data
- **WHEN** the test script runs
- **THEN** it MUST NEVER touch the production `./data/` directory
- **AND** the production `./data/` directory MUST remain unchanged
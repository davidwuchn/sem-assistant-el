# Specification: test-data-isolation

## MODIFIED Requirements

### Requirement: Test data directory is isolated from production
The system SHALL use a separate `./test-data/` directory for ephemeral test data and SHALL seed deterministic baseline org-roam fixtures into runtime test directories before each integration run.

#### Scenario: Test data directory is created at start
- **WHEN** the test script starts
- **THEN** if `./test-data/` exists, it MUST be deleted entirely
- **AND** then recreated with subdirectories: `test-data/org-roam`, `test-data/elfeed`, `test-data/morning-read`, `test-data/prompts`

#### Scenario: Baseline umbrella fixture is seeded before run
- **WHEN** test-data setup prepares `test-data/org-roam`
- **THEN** `dev/integration/testing-resources/20260313152244-llm.org` MUST be copied into the runtime org-roam test directory before URL-capture processing begins
- **AND** the seeded fixture MUST retain ID `96a58b04-1f58-47c9-993f-551994939252`

#### Scenario: Test data is git-ignored
- **WHEN** the test script runs
- **THEN** the `./test-data/` directory MUST be git-ignored

#### Scenario: Test data is separate from production data
- **WHEN** the test script runs
- **THEN** it MUST NEVER touch the production `./data/` directory
- **AND** the production `./data/` directory MUST remain unchanged

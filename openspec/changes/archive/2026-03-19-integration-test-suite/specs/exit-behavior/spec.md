## ADDED Requirements

### Requirement: Script exit behavior is well-defined
The system SHALL define clear exit semantics based on test outcomes.

#### Scenario: Exit code 0 on success
- **WHEN** all assertions pass
- **THEN** the script MUST exit with code 0

#### Scenario: Exit code 1 on failure
- **WHEN** any assertion fails
- **OR** timeout is reached
- **OR** daemon never becomes ready
- **OR** emacsclient trigger fails
- **THEN** the script MUST exit with code 1

#### Scenario: Artifact collection runs before exit
- **WHEN** the script exits for any reason
- **THEN** artifact collection MUST run before the EXIT trap fires (cleanup)

#### Scenario: Test data is preserved on exit
- **WHEN** the script exits
- **THEN** `test-data/` MUST NOT be deleted
- **AND** it MUST remain on disk for post-mortem inspection

#### Scenario: Test data is wiped at start of next run
- **WHEN** the script starts and `test-data/` exists
- **THEN** the script MUST delete `test-data/` entirely before recreating it

#### Scenario: Logs are wiped at script start
- **WHEN** the script starts
- **THEN** the script MUST wipe and recreate the `./logs/` directory
- **AND** this MUST happen before compose up
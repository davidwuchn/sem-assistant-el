## ADDED Requirements

### Requirement: Script polls for daemon readiness
The system SHALL poll for the Emacs daemon to accept connections before proceeding with inbox processing.

#### Scenario: Daemon readiness check uses emacsclient
- **WHEN** checking if daemon is ready
- **THEN** the script MUST run `podman exec sem-emacs emacsclient -e "t"`
- **AND** success is indicated by the command returning "t"

#### Scenario: Polling uses correct interval
- **WHEN** waiting for daemon readiness
- **THEN** the script MUST poll at 3-second intervals

#### Scenario: Polling has maximum attempts
- **WHEN** waiting for daemon readiness
- **THEN** the script MUST attempt a maximum of 30 polls (90 seconds total)

#### Scenario: Timeout sets failure status
- **WHEN** maximum attempts are exhausted without success
- **THEN** the script MUST print an error to stderr
- **AND** set FAIL status
- **AND** proceed directly to artifact collection
- **AND** exit with code 1
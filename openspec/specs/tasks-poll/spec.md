# Specification: tasks-poll

## Purpose

Define requirements for polling tasks.org completion.

## ADDED Requirements

### Requirement: Script polls for tasks.org completion
The system SHALL poll for `tasks.org` to contain all expected TODO entries before proceeding to assertions.

#### Scenario: Polling uses correct interval
- **WHEN** waiting for tasks.org completion
- **THEN** the script MUST poll at 5-second intervals

#### Scenario: Polling has maximum wait time
- **WHEN** waiting for tasks.org completion
- **THEN** the script MUST wait a maximum of 120 seconds (24 attempts)

#### Scenario: Completion checks for all expected TODO entries
- **WHEN** checking for completion
- **THEN** the script MUST GET `tasks.org` to a temp file
- **AND** count lines matching `^\* TODO ` using grep
- **AND** consider complete when count >= EXPECTED_TASK_COUNT
- **AND** EXPECTED_TASK_COUNT MUST be derived dynamically by counting `^\* TODO .*:task:` headlines in the test inbox file

#### Scenario: Timeout sets failure status without aborting
- **WHEN** maximum wait time is exhausted
- **THEN** the script MUST set FAIL status
- **AND** proceed to artifact collection
- **AND** NOT abort with set -e (use explicit status variable)

#### Scenario: Last successful GET is used as artifact
- **WHEN** tasks.org is successfully fetched
- **THEN** the temp file from the last successful GET MUST be used as the authoritative `tasks.org` artifact

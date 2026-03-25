## ADDED Requirements

### Requirement: End-to-end URL capture timeout is bounded to 5 minutes
The system SHALL enforce a single wall-clock timeout budget of 5 minutes for each URL-capture attempt from orchestration start to final outcome.

#### Scenario: Capture exceeds timeout budget
- **WHEN** a URL-capture attempt reaches 5 minutes without success
- **THEN** the attempt is terminated and no later than 5 minutes from start is classified as a timeout failure

#### Scenario: Capture completes within timeout budget
- **WHEN** a URL-capture attempt finishes before 5 minutes
- **THEN** the normal success or non-timeout failure path is used

### Requirement: Timeout failures are explicit FAIL outcomes with timeout logging
The system SHALL classify timeout expiration as `FAIL` and MUST emit timeout-specific log entries that are distinguishable from other failure types.

#### Scenario: Timeout produces explicit FAIL status
- **WHEN** a URL-capture attempt times out
- **THEN** logging records status `FAIL` with timeout-specific message content

#### Scenario: Non-timeout failures remain distinguishable
- **WHEN** a URL-capture attempt fails for non-timeout reasons
- **THEN** logging does not use timeout-specific classification

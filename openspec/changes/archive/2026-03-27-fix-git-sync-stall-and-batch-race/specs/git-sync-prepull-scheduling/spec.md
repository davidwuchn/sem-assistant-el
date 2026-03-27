## ADDED Requirements

### Requirement: Pre-pull runs on recurring cadence before inbox windows
The system SHALL execute a pre-pull operation on a recurring cadence that supports execution every 5 minutes. The schedule SHALL ensure at least one pre-pull run occurs 10 minutes or more before each inbox processing window.

#### Scenario: Recurring pre-pull cadence
- **WHEN** cron evaluates scheduled sync jobs over an hour
- **THEN** pre-pull is eligible to run every 5 minutes

#### Scenario: Pre-pull precedes inbox window
- **WHEN** an inbox processing window is scheduled
- **THEN** at least one successful pre-pull run is scheduled 10 minutes or more before that window

### Requirement: Pre-pull is idempotent and side-effect safe
Pre-pull SHALL reconcile remote updates without creating local commits or pushing local changes. Repeated pre-pull runs with no remote updates SHALL produce no duplicate repository side effects.

#### Scenario: No remote changes
- **WHEN** pre-pull runs and upstream has no new commits
- **THEN** no local commit is created
- **AND** no push is attempted

#### Scenario: Remote changes available
- **WHEN** pre-pull runs and upstream has new commits
- **THEN** local branch is updated by pull reconciliation only
- **AND** no local commit or push occurs during pre-pull

### Requirement: Pre-pull failures are explicit
If pre-pull fails due to authentication, network, or merge/rebase conflict conditions, the system SHALL log an explicit failure classification and SHALL NOT report success for that run.

#### Scenario: Pre-pull conflict
- **WHEN** pre-pull encounters a reconciliation conflict
- **THEN** the run is recorded as failure with conflict classification
- **AND** the system does not silently continue as success

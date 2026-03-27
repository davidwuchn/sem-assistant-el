## ADDED Requirements

### Requirement: SEM readiness probe returns deterministic functional state
The system SHALL provide a lightweight readiness probe function that reports ready/not-ready based on mandatory startup invariants for SEM workflow execution. The readiness result MUST be deterministic for the current process state and MUST NOT depend on external network availability.

#### Scenario: Probe reports ready after successful initialization
- **WHEN** required modules and startup dependencies are initialized successfully
- **THEN** the readiness probe returns a ready result

#### Scenario: Probe reports not-ready on missing startup invariant
- **WHEN** at least one required startup invariant is not satisfied
- **THEN** the readiness probe returns a not-ready result

### Requirement: Readiness probing is safe for frequent invocation
The readiness probe SHALL execute without triggering inbox processing, RSS generation, git sync, or other heavy workflows. The probe MUST avoid external network calls and side effects so watchdog and startup checks can run it frequently.

#### Scenario: Watchdog invokes readiness probe repeatedly
- **WHEN** watchdog executes on its configured cadence
- **THEN** each readiness probe call completes without running heavy workflows

#### Scenario: Startup gate invokes readiness probe before service handoff
- **WHEN** container startup performs readiness gating
- **THEN** the probe checks only startup invariants and returns without mutating workflow state

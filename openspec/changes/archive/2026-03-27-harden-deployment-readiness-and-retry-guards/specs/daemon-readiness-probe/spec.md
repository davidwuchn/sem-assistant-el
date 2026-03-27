## MODIFIED Requirements

### Requirement: SEM readiness probe returns deterministic functional state
The system SHALL provide a lightweight readiness probe function that reports ready/not-ready based on mandatory startup invariants for SEM workflow execution. Readiness success MUST require successful completion of dependency-load invariants, and logged dependency-load failures MUST force a not-ready result. The readiness result MUST be deterministic for the current process state and MUST NOT depend on external network availability.

#### Scenario: Probe reports ready after successful initialization
- **WHEN** required modules and startup dependencies are initialized successfully
- **THEN** the readiness probe returns a ready result

#### Scenario: Probe reports not-ready on missing startup invariant
- **WHEN** at least one required startup invariant is not satisfied
- **THEN** the readiness probe returns a not-ready result

#### Scenario: Dependency-load failure blocks healthy readiness
- **WHEN** dependency loading fails during startup and the failure is logged
- **THEN** readiness probe returns not-ready
- **AND** startup is not reported as healthy

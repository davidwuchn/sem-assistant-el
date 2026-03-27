## MODIFIED Requirements

### Requirement: Watchdog probes daemon liveness on a bounded cadence
The system SHALL run a daemon watchdog probe on a fixed cadence between 10 and 20 minutes, but probe success SHALL be determined by SEM readiness (functional startup state), not process liveness alone. Each probe SHALL use a bounded execution timeout.

#### Scenario: Watchdog uses readiness outcome for health decision
- **WHEN** the configured watchdog interval elapses
- **THEN** the watchdog executes one SEM readiness probe
- **AND** restart decisions use readiness result rather than daemon-process existence alone

#### Scenario: Probe timeout is enforced
- **WHEN** readiness probe execution exceeds the configured timeout
- **THEN** the probe is recorded as failed due to timeout

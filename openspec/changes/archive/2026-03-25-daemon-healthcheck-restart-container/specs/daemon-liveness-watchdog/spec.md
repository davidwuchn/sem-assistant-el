## ADDED Requirements

### Requirement: Watchdog probes daemon liveness on a bounded cadence
The system SHALL run a daemon liveness watchdog probe on a fixed cadence between 10 and 20 minutes. Each probe SHALL use `emacsclient` and SHALL enforce a hard timeout so probe execution cannot hang indefinitely.

#### Scenario: Probe runs on configured cadence
- **WHEN** the configured watchdog interval elapses
- **THEN** the system executes one daemon liveness probe

#### Scenario: Probe timeout is enforced
- **WHEN** daemon responsiveness check exceeds the configured timeout
- **THEN** the probe is recorded as failed due to timeout

### Requirement: Startup grace suppresses restart decisions
The system SHALL apply a startup grace period after container start during which failed probes MUST NOT trigger restart actions.

#### Scenario: Failed probe during startup grace
- **WHEN** a probe fails before startup grace has elapsed
- **THEN** the watchdog logs the failure and skips restart action

### Requirement: Watchdog executions are serialized
The system SHALL serialize watchdog executions so overlapping schedule invocations do not perform concurrent failure handling or restart attempts.

#### Scenario: Overlapping watchdog invocation
- **WHEN** a watchdog run is still active when the next schedule tick occurs
- **THEN** the later invocation exits without performing a second concurrent probe-and-restart flow

### Requirement: Confirmed liveness failure triggers idempotent restart action
The system SHALL trigger container recovery when a probe failure is confirmed outside startup grace by terminating the foreground keepalive process. The restart trigger SHALL be idempotent when the keepalive process is already absent.

#### Scenario: Probe failure outside startup grace
- **WHEN** a probe fails after startup grace has elapsed
- **THEN** the watchdog triggers keepalive process termination for container restart recovery

#### Scenario: Keepalive process already absent
- **WHEN** watchdog attempts restart trigger and the keepalive process is not running
- **THEN** the watchdog completes without error and records that restart action was already satisfied

### Requirement: Watchdog events are observable
The system SHALL emit logs for probe outcome, startup-grace suppression decisions, lock-contention skips, and restart-trigger actions.

#### Scenario: Successful probe logging
- **WHEN** a liveness probe succeeds
- **THEN** a success event is recorded in watchdog logs

#### Scenario: Restart decision logging
- **WHEN** watchdog triggers or suppresses a restart decision
- **THEN** the decision and reason are recorded in watchdog logs

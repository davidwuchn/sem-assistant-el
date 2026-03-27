# Specification: daemon-ready-poll

## Purpose

Define requirements for polling Emacs daemon readiness before inbox processing.

## ADDED Requirements

### Requirement: Script polls for daemon readiness
Startup entrypoint gating SHALL poll SEM readiness and MUST enter keepalive/tail behavior only after readiness succeeds. If readiness does not succeed within the configured polling window, startup MUST fail fast with non-zero exit status.

#### Scenario: Keepalive path starts only after readiness success
- **WHEN** startup polling observes a successful SEM readiness result
- **THEN** the entrypoint continues into keepalive/tail behavior

#### Scenario: Readiness timeout blocks keepalive and fails startup
- **WHEN** startup polling exhausts the maximum attempts without readiness success
- **THEN** the entrypoint exits with failure
- **AND** keepalive/tail behavior is not started

# Specification: integration-test-runner

## Purpose

Define requirements for the integration test runner Bash script.

## ADDED Requirements

### Requirement: Integration test runner script exists and is executable
The system SHALL provide a single Bash script at `dev/integration/run-integration-tests.sh` that executes the full integration test lifecycle.

#### Scenario: Script fails when OPENROUTER_KEY is not set
- **WHEN** the script is invoked without `OPENROUTER_KEY` environment variable set
- **THEN** the script MUST exit immediately with a clear error message indicating the missing environment variable

#### Scenario: Script uses podman-compose exclusively
- **WHEN** the script needs to start or stop containers
- **THEN** the script MUST use `podman-compose` and MUST NOT reference or use Docker

#### Scenario: Script accepts no arguments
- **WHEN** the script is invoked with any command-line arguments
- **THEN** the script MUST ignore all arguments and use only environment variables or hardcoded constants for configuration

#### Scenario: Script sets strict error handling
- **WHEN** the script starts execution
- **THEN** it MUST set `set -euo pipefail` at the top of the script

#### Scenario: Script registers cleanup trap first
- **WHEN** argument validation passes
- **THEN** the script MUST register a `trap ... EXIT` block as the FIRST action after validation that runs `podman-compose -f docker-compose.yml -f dev/integration/docker-compose.test.yml down -v` unconditionally

#### Scenario: Script checks exit codes on critical commands
- **WHEN** executing `podman`, `curl`, or `emacs --batch` commands
- **THEN** the script MUST check exit codes and MUST NOT silently swallow errors with `|| true` unless the specific silent-failure is documented inline with a comment

### Requirement: Integration test runner supports non-LLM git-sync local validation
The system SHALL provide a deterministic no-cost validation path in the integration test runner for git-sync behavior using only local resources.

#### Scenario: Local git-sync validation runs without OpenRouter key
- **WHEN** operators invoke the local git-sync validation path
- **THEN** the runner MUST execute without requiring `OPENROUTER_KEY`
- **AND** no LLM API calls are performed

#### Scenario: Local git-sync validation keeps paid inbox flow unchanged
- **WHEN** paid inbox/LLM integration tests run
- **THEN** existing paid workflow assertions remain unchanged
- **AND** local git-sync validation remains an independent execution path

### Requirement: Integration test compose override stays compatible with base Emacs service
The integration test workflow SHALL remain compatible with the base Emacs service while tolerating production WebDAV runtime substitution. The runner and compose override MUST keep artifact collection paths, container naming assumptions, and lifecycle orchestration deterministic.

#### Scenario: Runner lifecycle remains deterministic after WebDAV substitution
- **WHEN** integration tests execute with the test compose override
- **THEN** setup, execution, cleanup, and artifact collection complete using the same deterministic paths and container expectations
- **AND** production WebDAV runtime substitutions do not change test lifecycle contracts

### Requirement: Paid inbox integration run asserts cron/system timezone alignment
The paid inbox integration workflow SHALL include an explicit timezone assertion that validates cron/system runtime timezone alignment with `CLIENT_TIMEZONE` and persists timezone diagnostics into the run artifacts.

#### Scenario: Timezone assertion runs in paid inbox flow
- **WHEN** `run-integration-tests.sh` executes in paid inbox mode
- **THEN** the assertions phase emits `ASSERTION_9_RESULT:PASS|FAIL`
- **AND** final suite pass/fail status includes `ASSERTION_9_RESULT`

#### Scenario: Timezone diagnostics are persisted for debugging
- **WHEN** timezone assertion executes
- **THEN** diagnostics are written to a run artifact file under `test-results/`
- **AND** diagnostics include observed offset, expected offset, `/etc/localtime` resolution, `/etc/timezone`, and `TZ`

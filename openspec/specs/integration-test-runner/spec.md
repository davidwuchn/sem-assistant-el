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

### Requirement: Integration test compose override uses Eask-enabled Emacs image
The integration test compose override SHALL use an Emacs image that includes Eask tooling
so integration environments match the Eask-based package management workflow.

#### Scenario: Test compose override references Eask image
- **WHEN** `docker-compose.test.yml` is inspected
- **THEN** the Emacs service image is `silex/emacs:master-alpine-ci-eask`

#### Scenario: Integration test environment provides eask command
- **WHEN** integration test containers are started with the test compose override
- **THEN** the Emacs container environment has the `eask` command available

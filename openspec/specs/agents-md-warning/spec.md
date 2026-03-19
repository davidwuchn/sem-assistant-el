# Specification: agents-md-warning

## Purpose

Define requirements for warning agents about integration test dangers.

## ADDED Requirements

### Requirement: AGENTS.md warns agents not to run integration tests
The system SHALL add a section to `AGENTS.md` explicitly forbidding agents from running integration tests.

#### Scenario: AGENTS.md has integration test warning section
- **WHEN** `AGENTS.md` is read
- **THEN** there MUST be a section titled `## Integration Tests — DO NOT RUN`

#### Scenario: Warning states agents must never execute integration tests
- **WHEN** the integration test warning section is read
- **THEN** it MUST state that agents must never execute `dev/integration/run-integration-tests.sh`
- **AND** it MUST state that agents must never execute any `podman-compose` command referencing `docker-compose.test.yml`

#### Scenario: Warning mentions LLM API costs
- **WHEN** the integration test warning section is read
- **THEN** it MUST state that integration tests make real LLM API calls that cost money

#### Scenario: Warning states only human operator runs tests
- **WHEN** the integration test warning section is read
- **THEN** it MUST state that only the human operator runs integration tests

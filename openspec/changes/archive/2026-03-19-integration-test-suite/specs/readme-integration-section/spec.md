## ADDED Requirements

### Requirement: README.md documents integration test suite
The system SHALL add a section to `README.md` documenting the integration test suite.

#### Scenario: README has integration tests section
- **WHEN** `README.md` is read
- **THEN** there MUST be a section titled `## Integration Tests`

#### Scenario: Documentation mentions podman requirement
- **WHEN** the integration tests section is read
- **THEN** it MUST note that `podman` and `podman-compose` are required (not Docker)

#### Scenario: Documentation mentions OPENROUTER_KEY requirement
- **WHEN** the integration tests section is read
- **THEN** it MUST document that `OPENROUTER_KEY` must be set

#### Scenario: Documentation shows exact invocation command
- **WHEN** the integration tests section is read
- **THEN** it MUST document the exact invocation command from repository root

#### Scenario: Documentation shows results location
- **WHEN** the integration tests section is read
- **THEN** it MUST document where results are saved (`test-results/`)

#### Scenario: Documentation warns about API costs
- **WHEN** the integration tests section is read
- **THEN** it MUST warn that real LLM API calls are made and incur cost

#### Scenario: Documentation has explicit do-not-run warning
- **WHEN** the integration tests section is read
- **THEN** it MUST include the explicit note: **DO NOT RUN this script unless you intend to make real API calls.**
- **AND** it MUST state that the operator runs it manually
- **AND** it MUST state that it is never run automatically
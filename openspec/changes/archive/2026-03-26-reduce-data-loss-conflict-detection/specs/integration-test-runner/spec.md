## MODIFIED Requirements

### Requirement: Integration test compose override stays compatible with base Emacs service
The integration test workflow SHALL remain compatible with the base Emacs service while tolerating production WebDAV runtime substitution. The runner and compose override MUST keep artifact collection paths, container naming assumptions, and lifecycle orchestration deterministic.

#### Scenario: Runner lifecycle remains deterministic after WebDAV substitution
- **WHEN** integration tests execute with the test compose override
- **THEN** setup, execution, cleanup, and artifact collection complete using the same deterministic paths and container expectations
- **AND** production WebDAV runtime substitutions do not change test lifecycle contracts

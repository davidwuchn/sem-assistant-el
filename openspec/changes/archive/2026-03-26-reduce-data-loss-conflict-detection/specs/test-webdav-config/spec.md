## MODIFIED Requirements

### Requirement: Test WebDAV configuration file exists
The system SHALL provide `dev/integration/webdav-config.test.yml` for test environments with non-TLS operation. Test WebDAV configuration MUST remain independent from production Apache TLS runtime and conditional-write rejection settings so integration tests stay stable and local.

#### Scenario: Test config remains non-TLS and production-independent
- **WHEN** the test WebDAV config is loaded
- **THEN** TLS remains disabled and no production certificate paths are required
- **AND** production-only conditional-write enforcement is not required in test config

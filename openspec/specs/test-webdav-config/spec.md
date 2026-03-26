# Specification: test-webdav-config

## Purpose

Define requirements for test WebDAV configuration file.

## ADDED Requirements

### Requirement: Test WebDAV configuration file exists
The system SHALL provide `dev/integration/webdav-config.test.yml` for test environments with non-TLS operation. Test WebDAV configuration MUST remain independent from production Apache TLS runtime and conditional-write rejection settings so integration tests stay stable and local.

#### Scenario: Test WebDAV uses non-TLS
- **WHEN** the test WebDAV config is loaded
- **THEN** `server.tls` MUST be explicitly set to `false`

#### Scenario: Test WebDAV uses correct port
- **WHEN** the test WebDAV config is loaded
- **THEN** `server.port` MUST be set to `6065`

#### Scenario: Test WebDAV has no TLS certificates
- **WHEN** the test WebDAV config is loaded
- **THEN** no `cert` or `key` keys MUST be present in the configuration

#### Scenario: Test WebDAV uses environment-based credentials
- **WHEN** the test WebDAV config is loaded
- **THEN** the users block MUST use `{env}WEBDAV_USERNAME` and `{env}WEBDAV_PASSWORD`
- **AND** the scope MUST be `/data` with all permissions

#### Scenario: Test config remains non-TLS and production-independent
- **WHEN** the test WebDAV config is loaded
- **THEN** TLS remains disabled and no production certificate paths are required
- **AND** production-only conditional-write enforcement is not required in test config

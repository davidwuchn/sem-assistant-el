# Specification: test-webdav-config

## Purpose

Define requirements for test WebDAV configuration file.

## ADDED Requirements

### Requirement: Test WebDAV configuration file exists
The system SHALL provide a WebDAV configuration file at `dev/integration/webdav-config.test.yml` for the test environment.

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

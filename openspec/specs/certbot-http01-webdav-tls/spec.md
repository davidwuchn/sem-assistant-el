# Specification: certbot-http01-webdav-tls

## Purpose

Define production certificate issuance and renewal behavior for WebDAV TLS using Certbot HTTP-01.

## Requirements

### Requirement: Production Certbot HTTP-01 issuance
The system SHALL support automated certificate issuance for `WEBDAV_DOMAIN` using Certbot HTTP-01 in production. Issuance MUST require public DNS for `WEBDAV_DOMAIN` to resolve to the host and inbound TCP port 80 reachability for ACME challenge validation.

#### Scenario: First certificate issuance succeeds
- **WHEN** an operator enables Certbot automation for production with a valid `WEBDAV_DOMAIN` and reachable port 80
- **THEN** Certbot MUST complete HTTP-01 validation and issue a certificate for that domain
- **AND** issued certificate files MUST be written under the Let's Encrypt live-path consumed by WebDAV TLS

#### Scenario: Issuance preconditions are not met
- **WHEN** DNS resolution is incorrect or inbound TCP/80 is blocked during HTTP-01 validation
- **THEN** certificate issuance MUST fail explicitly
- **AND** the failure reason MUST be available to operators in service logs

### Requirement: Renewal automation preserves WebDAV certificate path compatibility
The system SHALL renew certificates with Certbot HTTP-01 while preserving the WebDAV certificate path contract consumed by production runtime after Apache migration. Renewal behavior MUST continue to update files under `/certs/live/<domain>/fullchain.pem` and `/certs/live/<domain>/privkey.pem` without requiring path changes.

#### Scenario: Renewal remains compatible after WebDAV runtime migration
- **WHEN** Certbot performs a successful renewal
- **THEN** renewed certificates remain available at the same live-path filenames used by production WebDAV
- **AND** Apache-based WebDAV continues serving TLS without certificate path reconfiguration

### Requirement: Production certificate state is isolated from integration tests
The system SHALL isolate Certbot-managed production certificate state from integration test execution. Integration workflows MUST NOT depend on Certbot issuance, HTTP-01 challenge networking, or host-level Let's Encrypt state.

#### Scenario: Integration run without Certbot prerequisites
- **WHEN** integration tests are executed in the test compose flow
- **THEN** test startup MUST not require Certbot service state, certificate issuance, or inbound port 80 challenge validation
- **AND** production certificate directories MUST not be a prerequisite for test success

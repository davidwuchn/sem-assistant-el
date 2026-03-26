## MODIFIED Requirements

### Requirement: Test compose override file exists
The system SHALL provide `dev/integration/docker-compose.test.yml` as a deterministic test override that remains independent from production TLS and Certbot state, even when production WebDAV runtime changes to Apache. Test startup MUST avoid any dependency on host `/etc/letsencrypt`, ACME challenge networking, or production-only conditional-write/TLS behavior.

#### Scenario: Test override remains Certbot-independent after runtime substitution
- **WHEN** test compose override is applied
- **THEN** test WebDAV startup does not require Certbot service state or host certificate directories
- **AND** non-TLS test execution remains deterministic

#### Scenario: Override excludes production-only WebDAV requirements
- **WHEN** integration tests run with override configuration
- **THEN** production Apache TLS and conditional-write hardening settings are not required for test WebDAV startup

# Specification: test-compose-override

## Purpose

Define integration test compose override behavior that remains isolated from production Certbot and TLS issuance constraints.

## MODIFIED Requirements

### Requirement: Test compose override file exists
The system SHALL provide a Compose override file at `dev/integration/docker-compose.test.yml` that modifies the production compose configuration for testing. The override MUST preserve test isolation by excluding any dependency on Certbot issuance, ACME challenge port 80 reachability, and host-level `/etc/letsencrypt` state.

#### Scenario: WebDAV service is overridden
- **WHEN** the test compose file is applied
- **THEN** the `webdav` service MUST override the volume mount of `webdav-config.yml` to use `dev/integration/webdav-config.test.yml`
- **AND** the `/etc/letsencrypt:/certs:ro` volume MUST be removed
- **AND** test certificates from `./dev/integration:/certs:ro,z` MUST be mounted
- **AND** `restart` MUST be set to `"no"`

#### Scenario: Emacs service is overridden
- **WHEN** the test compose file is applied
- **THEN** the `emacs` service MUST remove the `~/.ssh/vps-org-roam:/root/.ssh:ro` volume mount
- **AND** `restart` MUST be set to `"no"`

#### Scenario: Data volume is redirected to test directory
- **WHEN** the test compose file is applied
- **THEN** both `webdav` and `emacs` services MUST override the `./data:/data:rw` volume binding to `./test-data:/data:rw`

#### Scenario: Logs volume is preserved
- **WHEN** the test compose file is applied
- **THEN** both services MUST keep the `./logs:/var/log/sem:rw` volume binding unchanged

#### Scenario: Override inherits from base compose
- **WHEN** the test compose file is loaded
- **THEN** it MAY override service-level fields needed for test isolation (for example `image`, `environment`, `volumes`, and `restart`)
- **AND** it SHALL still rely on base compose for unspecified fields

#### Scenario: No Certbot or HTTP-01 dependency in test flow
- **WHEN** integration compose starts with the override
- **THEN** test startup MUST NOT require a Certbot service
- **AND** test startup MUST NOT require ACME challenge traffic on port 80
- **AND** test startup MUST NOT require existing host `/etc/letsencrypt` certificate state

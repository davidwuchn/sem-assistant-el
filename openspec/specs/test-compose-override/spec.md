# Specification: test-compose-override

## Purpose

Define requirements for Docker Compose test override file.

## ADDED Requirements

### Requirement: Test compose override file exists
The system SHALL provide a Compose override file at `dev/integration/docker-compose.test.yml` that modifies the production compose configuration for testing.

#### Scenario: WebDAV service is overridden
- **WHEN** the test compose file is applied
- **THEN** the `webdav` service MUST override the volume mount of `webdav-config.yml` to use `dev/integration/webdav-config.test.yml`
- **AND** the `/etc/letsencrypt:/certs:ro` volume MUST be removed
- **AND** the port mapping MUST be changed to `16065:6065`
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
- **THEN** it MUST NOT redefine image, build context, environment variables, or depends_on — those MUST be inherited from `docker-compose.yml`

## Purpose

TBD

## Requirements

### Requirement: Let's Encrypt certificate paths
Production WebDAV TLS configuration SHALL continue to use Let's Encrypt standard certificate filenames `fullchain.pem` and `privkey.pem` from `/certs/live/<domain>/`, with `<domain>` derived from `WEBDAV_DOMAIN`. This path contract SHALL be preserved while migrating runtime implementation to Apache configuration.

#### Scenario: Certificate file paths remain compatible
- **WHEN** inspecting production WebDAV TLS configuration
- **THEN** certificate and key paths resolve to `/certs/live/<domain>/fullchain.pem` and `/certs/live/<domain>/privkey.pem`
- **AND** `<domain>` is sourced from `WEBDAV_DOMAIN`

### Requirement: Docker compose mount unchanged
The `docker-compose.yml` WebDAV service certificate mount SHALL remain `/etc/letsencrypt:/certs:ro,z` and SHALL NOT be modified by this change.

#### Scenario: Certificate mount contract preserved
- **WHEN** inspecting production compose volumes for `webdav`
- **THEN** `/etc/letsencrypt:/certs:ro,z` is present
- **AND** no alternate cert mount path is required

### Requirement: WEBDAV_DOMAIN environment variable
The `.env.example` file SHALL include `WEBDAV_DOMAIN` with documentation explaining it must match the Let's Encrypt certificate domain. Production startup behavior SHALL fail fast when TLS is enabled but certificate files for `WEBDAV_DOMAIN` are missing, unreadable, or invalid.

#### Scenario: Environment variable documentation
- **WHEN** inspecting `.env.example`
- **THEN** it SHALL contain a `WEBDAV_DOMAIN` entry
- **AND** it SHALL include a comment explaining the variable must match the Let's Encrypt certificate domain

#### Scenario: Configurable domain
- **WHEN** an operator sets `WEBDAV_DOMAIN` in `.env`
- **THEN** the WebDAV container SHALL use certificates from `/etc/letsencrypt/live/$WEBDAV_DOMAIN/`
- **AND** TLS startup SHALL succeed if certificates exist at that path

#### Scenario: Missing or invalid certificate material
- **WHEN** TLS is enabled and required certificate files for `WEBDAV_DOMAIN` are missing, unreadable, or invalid
- **THEN** WebDAV startup MUST fail before serving traffic
- **AND** the failure MUST be visible in startup logs with actionable context

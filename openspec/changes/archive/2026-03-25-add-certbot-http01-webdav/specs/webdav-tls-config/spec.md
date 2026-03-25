# Specification: webdav-tls-config

## Purpose

Define updated WebDAV TLS configuration behavior for Certbot-managed certificate lifecycle.

## MODIFIED Requirements

### Requirement: Let's Encrypt certificate paths
The `webdav-config.yml` SHALL use Let's Encrypt standard certificate filenames: `fullchain.pem` for the certificate and `privkey.pem` for the private key. The paths SHALL reference `/certs/live/<domain>/` directory structure, and this path contract SHALL remain compatible with Certbot-managed certificate issuance and renewal.

#### Scenario: Certificate file paths
- **WHEN** inspecting `webdav-config.yml`
- **THEN** the `cert` field SHALL be set to `/certs/live/<domain>/fullchain.pem`
- **AND** the `key` field SHALL be set to `/certs/live/<domain>/privkey.pem`
- **AND** the `<domain>` placeholder SHALL be replaced with a shell-expandable environment variable reference

#### Scenario: Environment variable substitution
- **WHEN** inspecting the certificate paths in `webdav-config.yml`
- **THEN** the domain SHALL be specified as `{env}WEBDAV_DOMAIN`
- **AND** the WebDAV server SHALL expand this to the actual domain at runtime

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

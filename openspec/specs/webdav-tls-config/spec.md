## Purpose

TBD

## Requirements

### Requirement: Let's Encrypt certificate paths
Production TLS configuration SHALL support dual-domain operation for WebDAV and self-hosted organice using Let's Encrypt standard certificate filenames `fullchain.pem` and `privkey.pem` under `/certs/live/<domain>/`. The existing WebDAV certificate path contract derived from `WEBDAV_DOMAIN` SHALL remain intact, and organice HTTPS SHALL use the same path convention derived from the configured organice domain.

#### Scenario: WebDAV certificate path remains compatible
- **WHEN** inspecting production WebDAV TLS configuration
- **THEN** certificate and key paths resolve to `/certs/live/$WEBDAV_DOMAIN/fullchain.pem` and `/certs/live/$WEBDAV_DOMAIN/privkey.pem`

#### Scenario: Organice certificate path follows same convention
- **WHEN** inspecting production organice TLS configuration
- **THEN** certificate and key paths resolve to `/certs/live/$ORGANICE_DOMAIN/fullchain.pem` and `/certs/live/$ORGANICE_DOMAIN/privkey.pem`

### Requirement: Docker compose mount unchanged
The `docker-compose.yml` WebDAV service certificate mount SHALL remain `/etc/letsencrypt:/certs:ro,z` and SHALL NOT be modified by this change.

#### Scenario: Certificate mount contract preserved
- **WHEN** inspecting production compose volumes for `webdav`
- **THEN** `/etc/letsencrypt:/certs:ro,z` is present
- **AND** no alternate cert mount path is required

### Requirement: WEBDAV_DOMAIN environment variable
The runtime environment contract SHALL continue to require `WEBDAV_DOMAIN` and SHALL additionally require explicit organice domain configuration for self-hosted organice operation. Startup MUST fail fast when required domain variables or corresponding certificate files are missing, unreadable, or invalid.

#### Scenario: Domain variables are documented and explicit
- **WHEN** inspecting environment documentation and compose configuration
- **THEN** `WEBDAV_DOMAIN` remains required for WebDAV TLS
- **AND** organice domain configuration is explicitly documented and required for self-hosted organice HTTPS operation

#### Scenario: Missing domain or certificate prerequisites fail startup
- **WHEN** production startup is attempted without required domain variables or valid certificate files
- **THEN** startup fails before serving traffic
- **AND** logs identify which prerequisite failed

### Requirement: Organice image pinning is configurable without altering TLS contract
The runtime environment contract SHALL allow operators to pin the organice runtime image tag while preserving the existing TLS certificate path and domain behavior.

#### Scenario: Organice image can be pinned via environment
- **WHEN** inspecting compose configuration and environment documentation
- **THEN** operators can set an explicit organice image reference (for example via `ORGANICE_IMAGE`)
- **AND** changing the organice image reference does not alter certificate mount paths or domain variable requirements

### Requirement: Single Certbot automation service supports both certificate lineages
Certificate automation SHALL support both `WEBDAV_DOMAIN` and `ORGANICE_DOMAIN` certificate lineages from a single Certbot service instance and shared Let's Encrypt state volume. Renewal behavior MUST keep both lineages current without requiring a second Certbot container.

#### Scenario: Initial issuance supports both domains from one service
- **WHEN** operators configure both domains and run certificate issuance in production
- **THEN** the Certbot service can obtain certificates for both `WEBDAV_DOMAIN` and `ORGANICE_DOMAIN`
- **AND** issued files are available under `/certs/live/$WEBDAV_DOMAIN/` and `/certs/live/$ORGANICE_DOMAIN/`

#### Scenario: Renewal updates both lineages without duplicated Certbot services
- **WHEN** scheduled certificate renewal runs with both domain lineages present
- **THEN** renewal updates each lineage in place as needed
- **AND** deployment does not require separate Certbot containers per domain

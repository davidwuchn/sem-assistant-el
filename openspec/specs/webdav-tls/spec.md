## Purpose

TBD

## Requirements

### Requirement: Use hacdias/webdav with TLS support
The WebDAV service SHALL use Apache `httpd` with `mod_dav` for production WebDAV over HTTPS instead of `hacdias/webdav`. The service SHALL preserve the existing external TLS behavior on configured HTTPS port mapping and SHALL remain compatible with certificate files mounted from `/certs/live/<domain>/`.

#### Scenario: WebDAV startup with TLS
- **WHEN** the `docker-compose up` command is run
- **THEN** the `webdav` container starts using Apache `httpd` with WebDAV modules enabled
- **AND** HTTPS service starts using mounted certificate material

### Requirement: Environment variable substitution in config
WebDAV authentication and TLS domain configuration SHALL remain environment-driven in compose/runtime configuration, and production startup MUST fail explicitly when required auth or certificate configuration is missing.

#### Scenario: Runtime validates required environment-backed config
- **WHEN** production WebDAV starts with missing required credential or certificate configuration
- **THEN** startup fails before serving traffic
- **AND** logs provide actionable failure context

### Requirement: Production bootstrap order requires certificate readiness before secure startup
Production deployment and bootstrap guidance MUST require certificate readiness checks for both WebDAV and self-hosted organice domains before secure startup. Rollout behavior SHALL preserve service continuity for existing daemon and sync workflows by sequencing restarts to avoid unnecessary concurrent downtime.

#### Scenario: Dual-domain certificate readiness gates rollout
- **WHEN** an operator follows the production bootstrap flow for this change
- **THEN** certificate issuance and readability are verified for both WebDAV and organice domains before secure startup is attempted

#### Scenario: Rollout minimizes disruption to existing workflows
- **WHEN** WebDAV CORS policy and organice hosting changes are deployed
- **THEN** service restarts are sequenced to avoid prolonged unavailability of existing WebDAV-based sync workflows
- **AND** daemon scheduling behavior continues after rollout without data-format migration requirements

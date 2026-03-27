## MODIFIED Requirements

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
Production deployment and bootstrap guidance MUST require successful certificate issuance and certificate readability verification before operators execute production WebDAV startup paths that enforce TLS certificate mounts.

#### Scenario: Production startup is gated on certificate readiness
- **WHEN** an operator follows the production WebDAV bootstrap flow
- **THEN** certificate issuance and mounted certificate readability are verified before production startup is attempted
- **AND** startup guidance does not present production startup as a valid first step before certificate readiness

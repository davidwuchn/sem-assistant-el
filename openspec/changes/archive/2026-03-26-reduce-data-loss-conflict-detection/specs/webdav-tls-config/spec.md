## MODIFIED Requirements

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

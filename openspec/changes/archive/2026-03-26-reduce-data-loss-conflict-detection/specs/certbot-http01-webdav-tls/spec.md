## MODIFIED Requirements

### Requirement: Renewal automation preserves WebDAV certificate path compatibility
The system SHALL renew certificates with Certbot HTTP-01 while preserving the WebDAV certificate path contract consumed by production runtime after Apache migration. Renewal behavior MUST continue to update files under `/certs/live/<domain>/fullchain.pem` and `/certs/live/<domain>/privkey.pem` without requiring path changes.

#### Scenario: Renewal remains compatible after WebDAV runtime migration
- **WHEN** Certbot performs a successful renewal
- **THEN** renewed certificates remain available at the same live-path filenames used by production WebDAV
- **AND** Apache-based WebDAV continues serving TLS without certificate path reconfiguration

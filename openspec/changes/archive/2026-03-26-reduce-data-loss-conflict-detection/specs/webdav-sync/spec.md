## MODIFIED Requirements

### Requirement: WebDAV server exposes /data volume with HTTP Basic Auth
The system SHALL expose the `/data` directory over WebDAV protocol with HTTP Basic Authentication. Orgzly mobile clients SHALL sync against this endpoint, and conflicting stale uploads SHALL be rejected through conditional-write enforcement instead of silently replacing newer content.

#### Scenario: Orgzly syncs with explicit conflict rejection
- **WHEN** Orgzly is configured with endpoint URL, username, and password
- **THEN** Orgzly can list, upload, and download files from `/data`
- **AND** stale conflicting uploads are rejected with explicit precondition failure responses

#### Scenario: Concurrent updates do not silently overwrite
- **WHEN** client and server state diverge and a stale client upload is attempted
- **THEN** the server rejects the stale write
- **AND** newer server content remains preserved

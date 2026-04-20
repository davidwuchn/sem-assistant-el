## Purpose

This capability defines the WebDAV server that exposes the /data volume for Orgzly mobile sync.

## Requirements

### Requirement: WebDAV server exposes /data volume with HTTP Basic Auth
The system SHALL expose the `/data` directory over WebDAV protocol with HTTP Basic Authentication for data-bearing methods. Orgzly mobile clients and browser-based organice clients SHALL use this endpoint, and conflicting stale uploads SHALL be rejected through conditional-write enforcement instead of silently replacing newer content. Standards-required `OPTIONS` preflight handling is exempt from authentication, but this exemption MUST NOT relax authentication for read/write methods.

#### Scenario: Orgzly syncs with explicit conflict rejection
- **WHEN** Orgzly is configured with endpoint URL, username, and password
- **THEN** Orgzly can list, upload, and download files from `/data`
- **AND** stale conflicting uploads are rejected with explicit precondition failure responses

#### Scenario: Browser organice accesses WebDAV with credentials
- **WHEN** browser-based organice sends authenticated WebDAV data requests from the allowed origin
- **THEN** requests are authorized and processed under the same access controls as mobile clients

#### Scenario: Authentication is required for non-OPTIONS methods
- **WHEN** a client requests data-bearing WebDAV methods without credentials
- **THEN** the server returns HTTP 401 Unauthorized

#### Scenario: Concurrent updates do not silently overwrite
- **WHEN** client and server state diverge and a stale client upload is attempted
- **THEN** the server rejects the stale write
- **AND** newer server content remains preserved

### Requirement: WebDAV response headers are deterministic for origin-aware access
The system SHALL emit deterministic CORS response headers for allowed and disallowed origins so browser behavior is predictable and cache-safe. Responses for allowed origins MUST include explicit credential semantics and origin variance signaling.

#### Scenario: Allowed origin receives explicit variance and credentials headers
- **WHEN** a request includes an allowed origin
- **THEN** the response includes `Access-Control-Allow-Origin` for that origin and `Access-Control-Allow-Credentials: true`
- **AND** the response includes `Vary: Origin`

#### Scenario: Disallowed origin does not receive granted origin header
- **WHEN** a request includes a disallowed origin
- **THEN** the response does not grant that origin via `Access-Control-Allow-Origin`

### Requirement: WebDAV credentials configured via environment variables
The system SHALL read WebDAV username and password from environment variables (`WEBDAV_USERNAME`, `WEBDAV_PASSWORD`). Credentials SHALL NOT be hardcoded in configuration files or container images.

#### Scenario: Credentials loaded from environment
- **WHEN** the container starts with `WEBDAV_USERNAME` and `WEBDAV_PASSWORD` set in the environment
- **THEN** the WebDAV server authenticates users against these credentials

#### Scenario: Credentials have compose defaults
- **WHEN** `WEBDAV_USERNAME` or `WEBDAV_PASSWORD` is not set in the environment
- **THEN** the compose defaults are used for startup

### Requirement: Emacs lock files disabled to prevent WebDAV sync failures
The system SHALL disable Emacs lock file creation (`create-lockfiles nil`) to prevent `.#lock` files from syncing to Orgzly and causing sync conflicts.

#### Scenario: No lock files created during editing
- **WHEN** Emacs opens and edits an Org file in `/data`
- **THEN** no `.#filename` lock files are created in the directory

#### Scenario: Orgzly sync completes without lock file conflicts
- **WHEN** Orgzly syncs a directory where Emacs has recently edited files
- **THEN** no lock files appear in Orgzly and sync completes without errors

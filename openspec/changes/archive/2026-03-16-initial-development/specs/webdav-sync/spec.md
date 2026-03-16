## ADDED Requirements

### Requirement: WebDAV server exposes /data volume with HTTP Basic Auth
The system SHALL expose the `/data` directory over WebDAV protocol with HTTP Basic Authentication. Orgzly mobile clients SHALL connect to this endpoint to sync Org files bidirectionally.

#### Scenario: Orgzly connects and syncs files
- **WHEN** Orgzly is configured with the WebDAV endpoint URL, username, and password
- **THEN** Orgzly successfully lists, uploads, and downloads files from `/data`

#### Scenario: Authentication is required
- **WHEN** a client requests the WebDAV endpoint without credentials
- **THEN** the server returns HTTP 401 Unauthorized

#### Scenario: Concurrent reads are supported
- **WHEN** multiple Orgzly clients read files simultaneously
- **THEN** all clients receive consistent file content without errors

### Requirement: WebDAV credentials configured via environment variables
The system SHALL read WebDAV username and password hash from environment variables (`WEBDAV_USER`, `WEBDAV_HASH`). Credentials SHALL NOT be hardcoded in configuration files or container images.

#### Scenario: Credentials loaded from environment
- **WHEN** the container starts with `WEBDAV_USER` and `WEBDAV_HASH` set in the environment
- **THEN** the WebDAV server authenticates users against these credentials

#### Scenario: Missing credentials cause startup failure
- **WHEN** `WEBDAV_USER` or `WEBDAV_HASH` is not set in the environment
- **THEN** the WebDAV container fails to start and logs an error

### Requirement: Emacs lock files disabled to prevent WebDAV sync failures
The system SHALL disable Emacs lock file creation (`create-lockfiles nil`) to prevent `.#lock` files from syncing to Orgzly and causing sync conflicts.

#### Scenario: No lock files created during editing
- **WHEN** Emacs opens and edits an Org file in `/data`
- **THEN** no `.#filename` lock files are created in the directory

#### Scenario: Orgzly sync completes without lock file conflicts
- **WHEN** Orgzly syncs a directory where Emacs has recently edited files
- **THEN** no lock files appear in Orgzly and sync completes without errors

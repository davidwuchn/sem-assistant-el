## ADDED Requirements

### Requirement: WebDAV URL path uses /data/ prefix
The system SHALL construct WebDAV upload URLs with a `/data/` prefix in the path. The full URL SHALL be `${WEBDAV_BASE_URL}/data/inbox-mobile.org` (not `${WEBDAV_BASE_URL}/inbox-mobile.org`).

#### Scenario: WebDAV URL includes data prefix
- **WHEN** uploading the inbox file
- **THEN** the URL path is `${WEBDAV_BASE_URL}/data/inbox-mobile.org`

#### Scenario: WebDAV URL path structure
- **WHEN** the WebDAV base URL is `https://dav.example.com/webdav`
- **THEN** the upload URL is `https://dav.example.com/webdav/data/inbox-mobile.org`

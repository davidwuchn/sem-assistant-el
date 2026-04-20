## Purpose

Defines strict origin allowlist enforcement for credentialed browser access to WebDAV.

## Requirements

### Requirement: WebDAV CORS allowlist is explicit and single-origin
The WebDAV service SHALL permit credentialed cross-origin browser access only for the configured organice origin. The allowlist MUST be explicitly configured and MUST NOT default to wildcard access.

#### Scenario: Allowed origin receives credential-capable CORS headers
- **WHEN** a request includes an `Origin` header that exactly matches the configured organice origin
- **THEN** the response includes `Access-Control-Allow-Origin` for that exact origin
- **AND** the response includes `Access-Control-Allow-Credentials: true`

#### Scenario: Disallowed origin is rejected by CORS policy
- **WHEN** a request includes an `Origin` header that does not match the configured organice origin
- **THEN** the response does not grant cross-origin credential access
- **AND** no wildcard `Access-Control-Allow-Origin` value is returned

### Requirement: CORS policy forbids broad-trust defaults
The system MUST NOT use wildcard origins, dynamic origin reflection without allowlist checks, or implicit multi-origin trust for WebDAV browser access.

#### Scenario: Wildcard origin is never emitted
- **WHEN** WebDAV responds to cross-origin browser traffic
- **THEN** `Access-Control-Allow-Origin: *` is never returned for credentialed WebDAV routes

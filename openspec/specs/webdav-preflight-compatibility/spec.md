## Purpose

Defines browser-compatible CORS preflight handling for WebDAV while preserving authentication on data-bearing methods.

## Requirements

### Requirement: WebDAV supports unauthenticated CORS preflight requests
The WebDAV service SHALL handle `OPTIONS` preflight requests required by browser clients without requiring HTTP authentication. Preflight handling MUST return CORS policy headers consistent with the configured allowlist and MUST NOT perform data reads or writes.

#### Scenario: Valid preflight from allowed origin succeeds
- **WHEN** a browser sends an `OPTIONS` request with an allowed `Origin` and requested WebDAV method headers
- **THEN** the server responds successfully with required CORS preflight headers
- **AND** no authentication challenge is required for the preflight request

#### Scenario: Preflight from disallowed origin is not permitted
- **WHEN** a browser sends an `OPTIONS` request from a disallowed origin
- **THEN** the response does not authorize cross-origin access for that origin

### Requirement: Non-OPTIONS WebDAV methods remain authenticated
All non-`OPTIONS` WebDAV methods SHALL continue to require authenticated access and SHALL preserve existing authorization behavior.

#### Scenario: Unauthenticated data-bearing method is rejected
- **WHEN** a client sends `PROPFIND`, `GET`, `PUT`, or other data-bearing WebDAV methods without valid credentials
- **THEN** the server rejects the request as unauthorized

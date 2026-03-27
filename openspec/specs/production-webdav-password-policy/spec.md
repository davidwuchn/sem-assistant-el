## Purpose

Define production-only WebDAV password validation requirements that prevent weak credentials while preserving non-production and integration-test workflows.

## Requirements

### Requirement: Production WebDAV password policy is enforced at startup
In production mode, WebDAV startup SHALL reject credentials unless `WEBDAV_PASSWORD` is at least 20 characters long and includes at least one lowercase letter, one uppercase letter, and one digit.

#### Scenario: Weak production password fails validation
- **WHEN** production mode is enabled and `WEBDAV_PASSWORD` does not meet length or complexity policy
- **THEN** WebDAV startup fails before serving requests

#### Scenario: Strong production password passes validation
- **WHEN** production mode is enabled and `WEBDAV_PASSWORD` meets length and complexity policy
- **THEN** WebDAV startup continues normally

### Requirement: Password policy is production-only and test-compatible
The password policy enforcement SHALL apply only to production runtime. Non-production and integration-test runtime paths MUST remain exempt so existing test workflows continue to operate with test credentials.

#### Scenario: Integration test runtime bypasses production-only policy
- **WHEN** integration test runtime starts with non-production mode enabled
- **THEN** startup does not fail due to production password policy checks

#### Scenario: Production policy failures are visible
- **WHEN** production startup fails password validation
- **THEN** logs include an explicit validation failure reason suitable for operator remediation

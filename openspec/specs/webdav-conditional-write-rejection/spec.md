# Specification: webdav-conditional-write-rejection

## Purpose

Define production WebDAV conditional-write behavior to prevent stale clients from overwriting newer server content.

## Requirements

### Requirement: Production WebDAV rejects stale writes using conditional requests
The production WebDAV endpoint SHALL enforce conditional write semantics so stale client uploads are rejected instead of silently overwriting newer server content.

#### Scenario: Stale write is rejected
- **WHEN** a client attempts PUT with an out-of-date file precondition
- **THEN** the server rejects the write with a precondition failure response

#### Scenario: Fresh write succeeds
- **WHEN** a client submits PUT with a current precondition
- **THEN** the server accepts the write and persists the new content

### Requirement: Write conflicts require pull-before-push recovery
When a stale write is rejected, clients SHALL be required to refresh from server state before retrying upload.

#### Scenario: Rejected client must refresh before retry
- **WHEN** a stale write is rejected by the server
- **THEN** the client must pull the latest server version before a subsequent successful push

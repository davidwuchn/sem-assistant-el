## Purpose

Defines self-hosted HTTPS access for the organice web application and browser-based WebDAV login flows.

## Requirements

### Requirement: Operator-controlled organice endpoint is served over HTTPS
The system SHALL provide a self-hosted organice web application on an operator-controlled domain over HTTPS. The organice endpoint MUST be fronted by the existing reverse-proxy and certificate model so browser users do not require direct access to a separate publicly exposed organice application port.

#### Scenario: Organice endpoint is available on dedicated domain
- **WHEN** the operator configures the organice domain and deploys the stack
- **THEN** HTTPS requests to the organice domain return the organice application
- **AND** the endpoint is served through operator-managed infrastructure

#### Scenario: No direct public organice application port is required
- **WHEN** browser users access organice through the configured domain
- **THEN** organice login and file operations work without exposing a dedicated public organice container port

### Requirement: Browser WebDAV login flow is supported through first-party hosting
The system SHALL support browser-based organice WebDAV login and data access flows from the self-hosted organice origin to the configured WebDAV endpoint.

#### Scenario: Browser login succeeds from self-hosted origin
- **WHEN** a user enters valid WebDAV credentials in organice hosted on the configured origin
- **THEN** organice can authenticate and list repository files via WebDAV

## ADDED Requirements

### Requirement: Inbox processing is triggered synchronously
The system SHALL trigger inbox processing via emacsclient and wait for the command to return.

#### Scenario: Inbox trigger uses emacsclient
- **WHEN** triggering inbox processing
- **THEN** the script MUST run `podman exec sem-emacs emacsclient -e "(sem-core-process-inbox)"`

#### Scenario: Inbox trigger fails immediately on error
- **WHEN** triggering inbox processing and the command exits non-zero
- **THEN** the script MUST abort immediately with no retries

#### Scenario: Inbox trigger returns before LLM callbacks complete
- **WHEN** inbox processing is triggered
- **THEN** the emacsclient command MUST return immediately
- **AND** the poll step MUST handle async completion
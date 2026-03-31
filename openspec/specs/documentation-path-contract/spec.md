## Purpose

This capability defines the documentation contract for timezone configuration so operators can configure runtime scheduling semantics correctly.

## Requirements

### Requirement: CLIENT_TIMEZONE is documented as required configuration
Project configuration documentation SHALL require `CLIENT_TIMEZONE` and define it as an IANA timezone identifier that controls system-wide scheduling and time interpretation.

#### Scenario: Required variable is documented
- **WHEN** operators read configuration documentation
- **THEN** `CLIENT_TIMEZONE` appears as a required setting (not optional)

#### Scenario: Accepted format is documented
- **WHEN** operators read the `CLIENT_TIMEZONE` entry
- **THEN** documentation specifies valid IANA timezone names (for example `Europe/Belgrade`)

#### Scenario: System-wide effect is documented
- **WHEN** operators read timezone configuration guidance
- **THEN** documentation states that cron timing, scheduling semantics, purge window, digest date labels, and log day rollover follow `CLIENT_TIMEZONE`

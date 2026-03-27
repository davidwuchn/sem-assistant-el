## ADDED Requirements

### Requirement: README includes a constrained dummy VPS deployment guide
The README SHALL include an end-to-end dummy deployment walkthrough for VPS setup that is explicitly non-production and safe to copy for learning only.

#### Scenario: Dummy guide documents required setup flow
- **WHEN** the deployment guide is read
- **THEN** it MUST include `podman` and `podman-compose` installation steps for a VPS
- **AND** it MUST describe a `certbot` setup flow for certificate issuance and renewal
- **AND** it MUST document where required environment variables and password files are configured in this repository

#### Scenario: Dummy guide uses placeholder-only secrets and domains
- **WHEN** examples in the deployment guide show credentials, hostnames, or tokens
- **THEN** all values MUST be placeholders
- **AND** the guide MUST NOT include any real credential values or production domains

#### Scenario: Dummy guide repeats non-production constraints
- **WHEN** operators follow the deployment guide
- **THEN** the guide MUST clearly state that provider-specific production hardening is out of scope
- **AND** it MUST direct operators to apply their own production security controls separately

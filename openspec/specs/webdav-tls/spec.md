## Purpose

TBD

## Requirements

### Requirement: Use hacdias/webdav with TLS support
The WebDAV service SHALL use the `hacdias/webdav` Docker image and serve traffic over HTTPS (port 443 mapping to port 6065). The configuration MUST be provided via a mounted `config.yml` file.

#### Scenario: WebDAV startup with TLS
- **WHEN** the `docker-compose up` command is run
- **THEN** the `webdav` container starts using `hacdias/webdav` and listens for HTTPS connections using the host-mounted certificates.

### Requirement: Environment variable substitution in config
User credentials in the `config.yml` file MUST use `{env}WEBDAV_USERNAME` and `{env}WEBDAV_PASSWORD` variables to inherit values from the environment variables passed through `docker-compose.yml`.

#### Scenario: Authentication with environment variables
- **WHEN** a client attempts to authenticate via WebDAV
- **THEN** the server validates the credentials against the values provided in the `.env` file via environment variable substitution.

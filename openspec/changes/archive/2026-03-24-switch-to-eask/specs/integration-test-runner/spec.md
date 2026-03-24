## ADDED Requirements

### Requirement: Integration test compose override uses Eask-enabled Emacs image
The integration test compose override SHALL use an Emacs image that includes Eask tooling
so integration environments match the Eask-based package management workflow.

#### Scenario: Test compose override references Eask image
- **WHEN** `docker-compose.test.yml` is inspected
- **THEN** the Emacs service image is `silex/emacs:master-alpine-ci-eask`

#### Scenario: Integration test environment provides eask command
- **WHEN** integration test containers are started with the test compose override
- **THEN** the Emacs container environment has the `eask` command available

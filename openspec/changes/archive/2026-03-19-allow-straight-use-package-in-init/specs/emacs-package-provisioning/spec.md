## MODIFIED Requirements

### Requirement: Packages installed at container build time
All required Emacs packages SHALL be installed at container image build time using `straight.el`. No package installation SHALL occur at container runtime.

#### Scenario: Packages installed during docker build
- **WHEN** the Docker image is built
- **THEN** all packages are installed via `straight.el`

#### Scenario: No runtime package installation
- **WHEN** the container starts
- **THEN** `init.el` only calls `straight-use-package` for load-path activation of pre-built packages, never for network-based installation or downloading

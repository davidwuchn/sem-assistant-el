## MODIFIED Requirements

### Requirement: Packages installed at container build time
All required Emacs packages SHALL be installed at container image build time using Eask.
No package installation SHALL occur at container runtime.

#### Scenario: Packages installed during docker build
- **WHEN** the Docker image is built
- **THEN** all packages are installed via `eask install`

#### Scenario: No runtime package installation
- **WHEN** the container starts
- **THEN** `init.el` loads preinstalled packages with `require` and does not trigger network-based package installation

### Requirement: Dockerfile installs packages via batch emacs
The Dockerfile SHALL install packages with an Eask command during image build.

#### Scenario: Package installation in Dockerfile
- **WHEN** the Docker image is built
- **THEN** a Dockerfile `RUN` step executes `eask install`

### Requirement: Build fails if package installation fails
If dependency installation fails during build, the Docker build SHALL fail.
The build SHALL NOT silently continue with missing packages.

#### Scenario: Package failure fails build
- **WHEN** `eask install` fails
- **THEN** the Docker build exits with a non-zero status code

## REMOVED Requirements

### Requirement: bootstrap-packages.el separate from init.el
**Reason**: Package provisioning is moved to a root `Eask` manifest; a dedicated
`bootstrap-packages.el` installer file is no longer part of the architecture.

**Migration**: Remove `app/elisp/bootstrap-packages.el`, add a root `Eask` file, and update
startup code to rely on preinstalled dependencies resolved via Eask.

### Requirement: bootstrap-packages.el bootstraps straight.el
**Reason**: `straight.el` bootstrap is replaced by Eask-based dependency management.

**Migration**: Replace straight.el bootstrap and commit-pinned package recipes with Eask
dependency declarations and build-time `eask install`.

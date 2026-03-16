## Purpose

This capability defines the Emacs package provisioning system using straight.el for reproducible package installation at container build time.

## Requirements

### Requirement: Packages installed at container build time
All required Emacs packages SHALL be installed at container image build time using `straight.el`. No package installation SHALL occur at container runtime.

#### Scenario: Packages installed during docker build
- **WHEN** the Docker image is built
- **THEN** all packages are installed via `straight.el`

#### Scenario: No runtime package installation
- **WHEN** the container starts
- **THEN** `init.el` only calls `(require ...)`, never `straight-use-package`

### Requirement: straight.lockfile committed to repository
A `straight/versions/default.el` lockfile SHALL be committed to the repository at `/app/elisp/straight/versions/default.el`. This lockfile SHALL pin exact package revisions.

#### Scenario: Lockfile present in repo
- **WHEN** inspecting the repository
- **THEN** `straight/versions/default.el` exists and is committed

#### Scenario: Lockfile not gitignored
- **WHEN** checking `.gitignore`
- **THEN** `straight/versions/default.el` is NOT gitignored

### Requirement: bootstrap-packages.el separate from init.el
A dedicated `/app/elisp/bootstrap-packages.el` file SHALL contain only straight.el bootstrapping and package installation logic. This file SHALL be separate from `init.el`.

#### Scenario: bootstrap-packages.el exists
- **WHEN** inspecting `/app/elisp/`
- **THEN** `bootstrap-packages.el` is present as a separate file

#### Scenario: bootstrap-packages.el installs packages only
- **WHEN** `bootstrap-packages.el` is executed
- **THEN** it only bootstraps straight.el and installs packages, does not load `init.el` or any `sem-*.el` module

### Requirement: Dockerfile installs packages via batch emacs
The Dockerfile SHALL install packages with a RUN step:
```dockerfile
RUN emacs --batch --no-site-file --load /app/elisp/bootstrap-packages.el
```

#### Scenario: Package installation in Dockerfile
- **WHEN** the Docker image is built
- **THEN** `emacs --batch` runs `bootstrap-packages.el`

### Requirement: bootstrap-packages.el bootstraps straight.el
The `bootstrap-packages.el` file SHALL:
1. Bootstrap straight.el from its GitHub release
2. Load the lockfile via `straight-use-package`
3. Install `gptel`, `elfeed`, `elfeed-org`, `org-roam`, `websocket` using `(straight-use-package 'PKG)`

#### Scenario: straight.el bootstrapped
- **WHEN** `bootstrap-packages.el` runs
- **THEN** straight.el is bootstrapped from GitHub

#### Scenario: Lockfile loaded
- **WHEN** `bootstrap-packages.el` runs
- **THEN** the lockfile is loaded to pin package versions

#### Scenario: Required packages installed
- **WHEN** `bootstrap-packages.el` runs
- **THEN** `gptel`, `elfeed`, `elfeed-org`, `org-roam`, `websocket` are installed

### Requirement: Build fails if package installation fails
If a package fails to install during build, the Docker build SHALL fail. The build SHALL NOT silently continue with missing packages.

#### Scenario: Package failure fails build
- **WHEN** a package fails to install
- **THEN** the Docker build fails with non-zero exit code

# Specification: eask-package-management

## Purpose

Define requirements for Eask manifest-driven dependency management and Eask-backed test execution.

## ADDED Requirements

### Requirement: Eask manifest defines project dependencies
The repository SHALL include a root-level `Eask` file that declares all Emacs package
dependencies required by daemon runtime and unit tests.

#### Scenario: Eask manifest exists at repository root
- **WHEN** the repository root is inspected
- **THEN** an `Eask` file is present and parseable by the `eask` CLI

#### Scenario: Required packages declared in Eask
- **WHEN** the `Eask` file is evaluated
- **THEN** dependencies for `gptel`, `elfeed`, `elfeed-org`, `org-roam`, and `websocket` are declared

### Requirement: Eask installs dependencies in project-local storage
Dependency installation via Eask MUST place packages under `.eask/{EMACS-VERSION}/elpa/`
within the project workspace and MUST NOT require writes to user-global Emacs directories.

#### Scenario: Local installation path used
- **WHEN** `eask install` is executed in the project
- **THEN** package artifacts are created under `.eask/{EMACS-VERSION}/elpa/`

#### Scenario: Global Emacs directory not required
- **WHEN** dependency installation completes
- **THEN** project package provisioning succeeds without modifying `~/.emacs.d/`

### Requirement: Eask-backed test execution is supported
The project SHALL support running the ERT suite through Eask so dependency resolution and
load-path setup are provided by Eask instead of manual package stubbing.

#### Scenario: ERT suite runs via Eask
- **WHEN** `eask test ert` is invoked
- **THEN** tests are discovered and executed with dependencies available from Eask-managed paths

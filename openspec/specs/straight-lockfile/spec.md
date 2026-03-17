## Purpose

TBD

## Requirements

### Requirement: Valid straight.el lockfile format
The `app/elisp/straight/versions/default.el` file SHALL use valid straight.el lockfile syntax with `(straight-use-package '<pkg> :pin "<40-char-SHA>")` for each package. The non-existent `straight-versions` function SHALL be completely removed.

#### Scenario: Lockfile syntax validation
- **WHEN** inspecting `app/elisp/straight/versions/default.el`
- **THEN** it SHALL contain one `(straight-use-package ...)` call per package
- **AND** each call SHALL include a `:pin` argument with a 40-character SHA
- **AND** the file SHALL NOT contain any reference to `straight-versions`

#### Scenario: Required packages pinned
- **WHEN** the lockfile is loaded
- **THEN** it SHALL pin the following packages: `gptel`, `elfeed`, `elfeed-org`, `org-roam`, `websocket`
- **AND** each package SHALL have a valid 40-character commit SHA

#### Scenario: Lockfile structure
- **WHEN** inspecting the file content
- **THEN** it SHALL begin with a standard Elisp header
- **AND** it SHALL end with `(provide 'default)`
- **AND** it SHALL be syntactically valid Emacs Lisp

### Requirement: Lockfile activation
The `bootstrap-packages.el` file SHALL call `(straight-thaw-versions)` after the straight.el bootstrap block and before the `straight-use-package` calls to activate the lockfile.

#### Scenario: Lockfile activation sequence
- **WHEN** `bootstrap-packages.el` is executed
- **THEN** it SHALL bootstrap straight.el first
- **AND** it SHALL call `(straight-thaw-versions)` to load the lockfile
- **AND** THEN it SHALL install packages via `straight-use-package`

#### Scenario: Build reproducibility
- **WHEN** the Docker image is built
- **THEN** packages SHALL be installed at the exact SHAs specified in the lockfile
- **AND** builds SHALL be reproducible (same SHA produces same package versions)

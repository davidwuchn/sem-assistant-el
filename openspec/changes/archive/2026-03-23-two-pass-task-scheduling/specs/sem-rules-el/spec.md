## Purpose

This capability defines the `sem-rules.el` module that reads and parses the rules file.

## ADDED Requirements

### Requirement: sem-rules-read function exists
The module `sem-rules.el` SHALL provide the function `sem-rules-read` that returns the rules text as a string or `nil` if the file does not exist or is empty.

#### Scenario: File exists and has content
- **WHEN** `sem-rules-read` is called and `/data/rules.org` exists with content
- **THEN** it SHALL return the rules text as a string

#### Scenario: File does not exist
- **WHEN** `sem-rules-read` is called and `/data/rules.org` does not exist
- **THEN** it SHALL return `nil`

#### Scenario: File is empty
- **WHEN** `sem-rules-read` is called and `/data/rules.org` exists but is empty
- **THEN** it SHALL return `nil`

### Requirement: No runtime dependencies on other sem-* modules
The `sem-rules.el` module SHALL have no runtime `(require 'sem-*)` statements. It SHALL be loadable in isolation.

#### Scenario: Module loads without other sem-* modules
- **WHEN** `sem-rules.el` is loaded in a minimal Emacs environment
- **THEN** no `require` statements for other `sem-*` modules are executed

### Requirement: Module provides sem-rules
The module SHALL provide the feature `sem-rules` via `(provide 'sem-rules)`.

#### Scenario: Module provides sem-rules
- **WHEN** `sem-rules.el` is loaded
- **THEN** the feature `sem-rules` is available

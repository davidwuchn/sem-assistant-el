# Specification: gitignore

## Purpose

Define requirements for gitignore entries for test directories.

## ADDED Requirements

### Requirement: Gitignore includes test directories
The system SHALL update `.gitignore` to ignore test-related directories.

#### Scenario: Gitignore ignores test-results
- **WHEN** `.gitignore` is read
- **THEN** it MUST contain an entry for `test-results/`

#### Scenario: Gitignore ignores test-data
- **WHEN** `.gitignore` is read
- **THEN** it MUST contain an entry for `test-data/`

#### Scenario: Gitignore is created if absent
- **WHEN** `.gitignore` does not exist
- **THEN** a new `.gitignore` file MUST be created with at least the `test-results/` and `test-data/` entries

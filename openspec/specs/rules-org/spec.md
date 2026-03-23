## Purpose

This capability defines the rules file format and semantics for user scheduling preferences.

## ADDED Requirements

### Requirement: rules-org file location
The system SHALL use `/data/rules.org` as the user preferences file for scheduling decisions. This file SHALL be synced via WebDAV alongside `inbox-mobile.org` and `tasks.org`.

#### Scenario: rules.org accessible via WebDAV
- **WHEN** the user edits `/data/rules.org` via WebDAV
- **THEN** the changes are synced to the daemon's filesystem

### Requirement: rules-org format is plain text org-mode
The rules file SHALL be plain text using org-mode headline syntax. The file SHALL contain a headline `* My Scheduling Preferences` followed by natural language rules, one per line.

#### Scenario: Example rules.org content
- **WHEN** rules.org contains:
  ```
  * My Scheduling Preferences
  
  I'm free for routine tasks usually from 16:00 PM.
  I prefer do not do work things on weekend.
  Family tasks can be scheduled any time.
  ```
- **THEN** the rules text returned SHALL be the natural language content after the headline

### Requirement: Missing rules.org is not an error
If `/data/rules.org` does not exist, the system SHALL treat this as if the file is empty. The rules text SHALL be `nil` and the system SHALL degrade gracefully to behavior without rules.

#### Scenario: Missing rules.org returns nil
- **WHEN** `/data/rules.org` does not exist
- **THEN** `sem-rules-read` SHALL return `nil`

### Requirement: Empty rules.org treated as missing
If `/data/rules.org` exists but is empty or contains only whitespace, the system SHALL treat it as if the file does not exist.

#### Scenario: Empty rules.org returns nil
- **WHEN** `/data/rules.org` exists but has no content
- **THEN** `sem-rules-read` SHALL return `nil`

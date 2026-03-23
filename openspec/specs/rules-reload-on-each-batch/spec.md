## Purpose

This capability defines that rules.org is read fresh before every batch, allowing rule changes without daemon restart.

## ADDED Requirements

### Requirement: Rules read at call time
The `rules.org` file SHALL be read fresh at the start of each `sem-core-process-inbox` call, not at module load time.

#### Scenario: Rules read at batch start
- **WHEN** `sem-core-process-inbox` starts
- **THEN** `sem-rules-read` is called to get current rules

### Requirement: No daemon restart needed for rule changes
Since rules are read at call time, changes to `rules.org` take effect on the next cron run without daemon restart.

#### Scenario: Rule change takes effect next cron
- **WHEN** the user edits rules.org via WebDAV
- **THEN** the new rules are used on the next inbox processing run

### Requirement: Rules prepended to user prompt section in Pass 1
The rules text SHALL be prepended to the user prompt section in Pass 1 when constructing the LLM prompt.

#### Scenario: Rules in Pass 1 prompt
- **WHEN** Pass 1 prompt is constructed
- **THEN** the rules text from rules.org is prepended to the user prompt section

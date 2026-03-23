## Purpose

This capability defines the LLM pipeline for processing `@task` tagged headlines from the inbox, generating structured Org TODO entries with auto-tagging and validation.

## ADDED Requirements

### Requirement: rules text injected into Pass 1 prompt
The Pass 1 prompt SHALL inject the rules text from `rules.org` when constructing the user prompt section. Rules SHALL be prepended to the user prompt.

#### Scenario: Rules injected in Pass 1
- **WHEN** `sem-router--route-to-task-llm` constructs the Pass 1 prompt
- **THEN** rules text from rules.org is prepended to the user prompt section

### Requirement: Pass 1 asks for time range guess
The Pass 1 prompt SHALL ask the LLM to guess a provisional time range in format `SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>`.

#### Scenario: Pass 1 asks for time range
- **WHEN** Pass 1 prompt is constructed
- **THEN** it instructs the LLM to provide a provisional SCHEDULED with time range

### Requirement: Provisional SCHEDULED is hint only
The provisional SCHEDULED from Pass 1 SHALL be treated as a hint. Pass 2 may override it with different timing.

#### Scenario: Provisional SCHEDULED marked as hint
- **WHEN** Pass 1 returns a time range
- **THEN** Pass 2 knows this is provisional and may override it

### Requirement: Pass 1 writes to batch temp file
Pass 1 results SHALL be written to the batch temp file `/tmp/data/tasks-tmp-{batch-id}.org` instead of directly to tasks.org.

#### Scenario: Pass 1 writes to temp file
- **WHEN** Pass 1 generates a task entry
- **THEN** it is written to the batch temp file

### Requirement: Pass 1 uses same validation and security processing
Pass 1 SHALL use the same `sem-router--validate-task-response` for validation and `sem-security-*` functions for body sanitization as before.

#### Scenario: Validation still applies
- **WHEN** Pass 1 validates LLM output
- **THEN** `sem-router--validate-task-response` is used

#### Scenario: Security processing still applies
- **WHEN** Pass 1 processes headline with body
- **THEN** `sem-security-sanitize-for-llm` and `sem-security-restore-from-llm` are used

## REMOVED Requirements

### Requirement: Direct write to tasks.org after each callback
**Reason**: Replaced by batch temp file approach. Writes now go to temp file during Pass 1; final write to tasks.org happens after Pass 2 via atomic update.

**Migration**: Use `sem-router--write-task-to-file` is no longer called after each callback. Instead, Pass 1 results accumulate in batch temp file. The final tasks.org write is handled by `sem-planner--atomic-tasks-org-update` after Pass 2.

### Requirement: tasks.org writes protected by mutex
**Reason**: Pass 1 writes go to batch-local temp file which is not shared during Pass 1. The atomic `rename-file` approach provides sufficient safety for the final tasks.org write without requiring a mutex.

**Migration**: No mutex is used. The atomic `rename-file` to write final tasks to tasks.org provides sufficient protection against partial writes.

## Purpose

This capability defines the LLM pipeline for processing `@task` tagged headlines from the inbox, generating structured Org TODO entries with auto-tagging and validation.

## ADDED Requirements

### Requirement: @task headlines routed to LLM pipeline
The system SHALL detect headlines tagged with `@task`. These headlines SHALL be routed to `sem-router--route-to-task-llm` instead of being silently discarded. The LLM SHALL return a single valid Org TODO entry with cleaned title, optional DEADLINE/SCHEDULED/PRIORITY, description, and a `:PROPERTIES:` drawer.

#### Scenario: @task headline routed to LLM
- **WHEN** a headline has the tag `@task` (e.g. `* Task description :@task:`)
- **THEN** `sem-router.el` calls `sem-router--route-to-task-llm` with the headline content

#### Scenario: LLM returns structured TODO entry
- **WHEN** the LLM processes an `@task` headline
- **THEN** the response contains a valid Org TODO entry with title, properties drawer, and description

### Requirement: Task entry includes :PROPERTIES: drawer with :ID:
The LLM-generated task entry SHALL include a `:PROPERTIES:` drawer containing `:ID:` generated via `org-id`. The `:ID:` value SHALL be a valid UUID or org-id format.

#### Scenario: Properties drawer present
- **WHEN** the LLM returns a task entry
- **THEN** the entry includes a `:PROPERTIES:` drawer

#### Scenario: ID field present in properties
- **WHEN** the properties drawer is present
- **THEN** it contains an `:ID:` field with a valid org-id value

### Requirement: Task entry includes :FILETAGS: from allowed list
The LLM-generated task entry SHALL include `:FILETAGS:` set to exactly one tag from the allowed list: `("work" "family" "routine" "opensource")`. The Elisp layer SHALL validate the tag and substitute `:routine:` if the LLM returns an absent or invalid tag.

#### Scenario: Valid tag returned by LLM
- **WHEN** the LLM returns a `:FILETAGS:` with a valid tag from the allowed list
- **THEN** the tag is preserved as-is in the written entry

#### Scenario: Invalid tag substituted with routine
- **WHEN** the LLM returns a `:FILETAGS:` with a tag not in the allowed list
- **THEN** the Elisp layer substitutes `:routine:` before writing

#### Scenario: Absent tag substituted with routine
- **WHEN** the LLM returns a task entry missing `:FILETAGS:`
- **THEN** the Elisp layer adds `:FILETAGS: routine:` before writing

### Requirement: Task entry appended to tasks.org
The validated task entry SHALL be appended to `/data/tasks.org`. The file SHALL be created if it does not exist.

#### Scenario: Task appended to existing file
- **WHEN** `/data/tasks.org` exists
- **THEN** the validated task entry is appended to the file

#### Scenario: tasks.org created if absent
- **WHEN** `/data/tasks.org` does not exist
- **THEN** the file is created and the task entry is written

### Requirement: Retry/DLQ policy same as url-capture
The task LLM pipeline SHALL follow the same retry/DLQ policy as `sem-url-capture-process`: API errors leave the hash unrecorded (retry next cron); malformed LLM output goes to `errors.org` and marks the hash as processed (no infinite retry).

#### Scenario: API error triggers retry
- **WHEN** the LLM API returns an error (429 rate limit, timeout)
- **THEN** the headline hash is NOT added to `.sem-cursor.el` and retries next cron run

#### Scenario: Malformed output sent to DLQ
- **WHEN** the LLM returns malformed output (missing `:PROPERTIES:`, `:ID:`, or invalid structure)
- **THEN** the raw response and original input are appended to `/data/errors.org`

#### Scenario: DLQ entry marked processed
- **WHEN** malformed output is sent to the Dead Letter Queue
- **THEN** the headline hash is added to `.sem-cursor.el` to prevent infinite retry

### Requirement: sem-llm-request used for LLM calls
The task LLM pipeline SHALL use `sem-llm-request` for all LLM API calls, ensuring consistent retry handling, logging, and cursor management across all LLM interactions.

#### Scenario: sem-llm-request called for task processing
- **WHEN** processing an `@task` headline
- **THEN** `sem-llm-request` is called (not direct `gptel-request`)

#### Scenario: Hash passed to sem-llm-request
- **WHEN** `sem-llm-request` is called for task processing
- **THEN** the headline's content hash is passed as the `hash` argument for cursor tracking

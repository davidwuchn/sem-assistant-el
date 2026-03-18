## Purpose

This capability defines the LLM pipeline for processing `@task` tagged headlines from the inbox, generating structured Org TODO entries with auto-tagging and validation.

## MODIFIED Requirements

### Requirement: Security block destructuring uses car and cdr
The function `sem-router--route-to-task-llm` SHALL correctly destructure the return value of `sem-security-sanitize-for-llm`. The result is a cons cell where `(car result)` is the sanitized body text and `(cdr result)` is the security blocks alist.

#### Scenario: Correct destructuring of sanitize result
- **WHEN** `sem-security-sanitize-for-llm` returns a cons cell
- **THEN** `sanitized-body` is bound to `(car result)`
- **AND** `security-blocks` is bound to `(cdr result)`

#### Scenario: Security blocks passed to restore function
- **WHEN** restoring security blocks after LLM response
- **THEN** only the `cdr` (blocks alist) is passed to `sem-security-restore-from-llm`
- **AND** the full cons cell is NOT passed

### Requirement: Empty body proceeds with LLM call
When `sanitized-body` is the empty string after sanitization, the LLM call SHALL proceed with an empty body. The system SHALL NOT skip the LLM call for empty bodies.

#### Scenario: Empty body after sanitization
- **WHEN** `sanitized-body` equals `""`
- **THEN** the LLM call proceeds with an empty body
- **AND** the task is processed normally

#### Scenario: Zero-body headline is valid
- **WHEN** a headline has no body content
- **THEN** it is still routed to the LLM with empty body
- **AND** the LLM generates a TODO entry from the title only

### Requirement: Task LLM pipeline receives and uses body content
The function `sem-router--route-to-task-llm` SHALL read the `:body` key from the headline plist. If `:body` is non-nil, it SHALL call `sem-security-sanitize-for-llm` on the body text, store the returned `security-blocks` in the context plist, and append a `BODY:` section to the user prompt after the `HEADLINE:` line. After the LLM response arrives, it SHALL call `sem-security-restore-from-llm` using the stored `security-blocks` before passing the response to `sem-router--validate-task-response`.

#### Scenario: @task with body sanitizes and includes in prompt
- **WHEN** `sem-router--route-to-task-llm` receives a headline with non-nil `:body`
- **THEN** it calls `sem-security-sanitize-for-llm` on the body
- **AND** it appends `\nBODY:\n<sanitized-body>` to the user prompt
- **AND** it stores `security-blocks` in the context plist

#### Scenario: @task with nil body skips body handling
- **WHEN** `sem-router--route-to-task-llm` receives a headline with `:body` equal to `nil`
- **THEN** no `BODY:` section is added to the prompt
- **AND** no security sanitization is performed

#### Scenario: LLM response restored before validation
- **WHEN** the LLM returns a response for a headline that had body content
- **THEN** `sem-security-restore-from-llm` is called with the response and stored `security-blocks`
- **AND** the restored response is passed to `sem-router--validate-task-response`

#### Scenario: Context plist contains security blocks
- **WHEN** `sem-llm-request` is called for an `@task` with body
- **THEN** the context plist contains `:injected-id`, `:hash`, and `:security-blocks`

## ADDED Requirements

### Requirement: tasks.org writes protected by mutex
All writes to `/data/tasks.org` from `sem-router--route-to-task-llm` SHALL be protected by the `sem-router--tasks-write-lock` mutex. The callback SHALL acquire the lock before writing and release it after.

#### Scenario: Lock acquired before write
- **WHEN** a callback is ready to write to tasks.org
- **THEN** it acquires `sem-router--tasks-write-lock` before calling `write-region`

#### Scenario: Lock released after write
- **WHEN** the write to tasks.org completes
- **THEN** the lock is released via `unwind-protect`

#### Scenario: Retry on lock contention
- **WHEN** the lock is held by another callback
- **THEN** the current callback re-schedules itself with 0.5s delay
- **AND** retries up to 10 times before routing to DLQ

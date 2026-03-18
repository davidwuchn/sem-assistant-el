## ADDED Requirements

### Requirement: Body content appended to LLM prompt for @task headlines
For headlines tagged with `@task` that have non-nil `:body`, the system SHALL append a `BODY:` section to the LLM user prompt after the `HEADLINE:` section. The body text SHALL be passed through `sem-security-sanitize-for-llm` before being added to the prompt. The returned `security-blocks` alist SHALL be stored in the LLM context plist alongside `:injected-id` and `:hash`.

#### Scenario: @task with body includes BODY section in prompt
- **WHEN** processing an `@task` headline with `:body` containing `"Task description details"`
- **THEN** the LLM prompt contains `\nBODY:\n<Task description details>` after the HEADLINE section

#### Scenario: @task with nil body omits BODY section
- **WHEN** processing an `@task` headline with `:body` equal to `nil`
- **THEN** the LLM prompt contains no `BODY:` section

#### Scenario: Body sanitized before LLM send
- **WHEN** processing an `@task` headline with body containing `#+begin_sensitive\nsecret\n#+end_sensitive`
- **THEN** `sem-security-sanitize-for-llm` is called on the body text before adding to prompt
- **AND** the sanitized content is used in the prompt

### Requirement: LLM response restored using stored security blocks
After receiving the LLM response, the system SHALL call `sem-security-restore-from-llm` on the response using the stored `security-blocks` alist before passing the response to `sem-router--validate-task-response`.

#### Scenario: Response restored after LLM returns
- **WHEN** the LLM returns a response for an `@task` headline that had body content
- **THEN** `sem-security-restore-from-llm` is called with the response and stored `security-blocks`
- **AND** the restored response is passed to validation

#### Scenario: No restoration for headlines without body
- **WHEN** the LLM returns a response for an `@task` headline that had no body content
- **THEN** no security restoration is performed (no security-blocks stored)
- **AND** the original response is passed directly to validation

### Requirement: Security blocks stored in context plist
The system SHALL store the `security-blocks` alist returned by `sem-security-sanitize-for-llm` in the context plist that is passed through the LLM request pipeline, alongside the existing `:injected-id` and `:hash` entries.

#### Scenario: Security blocks available in callback
- **WHEN** `sem-llm-request` callback is invoked for an `@task` with body
- **THEN** the context plist contains `:security-blocks` with the alist from sanitization

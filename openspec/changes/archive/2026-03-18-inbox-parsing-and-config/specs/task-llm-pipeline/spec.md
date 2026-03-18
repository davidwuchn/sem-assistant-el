## MODIFIED Requirements

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

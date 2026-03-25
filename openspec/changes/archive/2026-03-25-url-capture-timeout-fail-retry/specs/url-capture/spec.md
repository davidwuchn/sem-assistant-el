## MODIFIED Requirements

### Requirement: url-capture pipeline triggered by inbox-processing
The system SHALL provide `sem-url-capture-process` as a non-interactive function callable from `sem-router.el`. The function SHALL accept a URL and headline metadata, run the full capture pipeline under a single 5-minute end-to-end timeout guard, and return the saved filepath on success or `nil` on failure.

#### Scenario: url-capture called with valid URL
- **WHEN** `sem-router.el` calls `sem-url-capture-process` with a URL from a `:link:` headline
- **THEN** the full pipeline executes: fetch, sanitize, query umbrella nodes, LLM, validate, save

#### Scenario: Success returns filepath
- **WHEN** the pipeline completes successfully
- **THEN** `sem-url-capture-process` returns the absolute filepath of the saved org-roam node

#### Scenario: Failure returns nil
- **WHEN** any step in the pipeline fails (trafilatura error, LLM error, validation failure)
- **THEN** `sem-url-capture-process` returns `nil`

#### Scenario: Timeout returns nil within 5 minutes
- **WHEN** the orchestration timeout budget is reached
- **THEN** `sem-url-capture-process` returns `nil` with timeout classified as `FAIL`

## ADDED Requirements

### Requirement: Reasoning exclusion for thinking models
The `sem-llm` module SHALL support reasoning exclusion via gptel backend request-params. When configured with `:request-params '(:reasoning (:exclude t))`, the LLM response SHALL NOT include thinking traces from reasoning models.

#### Scenario: Reasoning exclusion configured
- **WHEN** gptel backend is configured with reasoning exclusion
- **THEN** reasoning model responses exclude thinking traces

#### Scenario: Reasoning exclusion not configured
- **WHEN** gptel backend lacks reasoning exclusion
- **THEN** LLM responses include full content including thinking traces

### Requirement: Comprehensive logging with token estimates
The `sem-llm` module SHALL log detailed information for all LLM requests:
- Prompt length in characters on request initiation (token estimate = length/4)
- Response length and token count on success
- Full error details with input recorded on failure

#### Scenario: Request initiation logged
- **WHEN** `sem-llm-request` is called
- **THEN** `sem-core-log` is called with prompt length (token estimate = length/4)

#### Scenario: Success logged with token count
- **WHEN** an LLM request completes successfully
- **THEN** `sem-core-log` is called with response length and token count

#### Scenario: Failure logged with input
- **WHEN** an LLM request fails
- **THEN** `sem-core-log-error` is called with error details and input text

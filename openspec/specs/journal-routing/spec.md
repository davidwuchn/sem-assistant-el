## Purpose

This capability defines deterministic inbox routing behavior for `:journal:`-tagged headlines.

## Requirements

### Requirement: Journal-tagged headlines are routed to deterministic journal processing
The system SHALL detect headlines tagged with `:journal:` and route them to a deterministic journal processing path. This route MUST bypass the task LLM and URL capture pipelines.

#### Scenario: Journal headline routed to journal processor
- **WHEN** a headline includes the `:journal:` tag
- **THEN** the router sends the headline to the journal processing path
- **AND** the task LLM route is not invoked for that headline

#### Scenario: Journal route ignores task and link pipelines
- **WHEN** a `:journal:` headline is processed in an inbox batch
- **THEN** `sem-router--route-to-task-llm` is not called for that headline
- **AND** `sem-url-capture-process` is not called for that headline

## MODIFIED Requirements

### Requirement: inbox-mobile.org non-existence handled gracefully
The system SHALL handle the case where `/data/inbox-mobile.org` does not exist when the cron job fires. The daemon SHALL log a warning and exit cleanly without creating the file. The function `sem-router--parse-headlines` SHALL be wrapped in `(cl-block sem-router--parse-headlines ...)` to support `cl-return-from` usage without crashing.

#### Scenario: Missing inbox file logs warning
- **WHEN** the cron job fires and `/data/inbox-mobile.org` does not exist
- **THEN** a warning is logged to `/data/sem-log.org` and the function exits cleanly

#### Scenario: Daemon does not create inbox-mobile.org
- **WHEN** `/data/inbox-mobile.org` is absent
- **THEN** the daemon does not create it; Orgzly is the sole creator

#### Scenario: cl-return-from does not crash
- **WHEN** `sem-router--parse-headlines` executes with `cl-return-from` statements
- **THEN** no crash occurs due to missing `cl-block` wrapper

### Requirement: @task tagged headlines routed to task LLM pipeline
The system SHALL detect headlines tagged with `@task`. These headlines SHALL be routed to `sem-router--route-to-task-llm` for LLM processing instead of being silently discarded. The routing SHALL occur in `sem-router--route-headline` after checking for `@link` tags.

#### Scenario: @task headline routed to task LLM
- **WHEN** a headline has the tag `@task` (e.g. `* Task description :@task:`)
- **THEN** `sem-router.el` calls `sem-router--route-to-task-llm` with the headline content

#### Scenario: @task headline not silently discarded
- **WHEN** an `@task` headline is processed
- **THEN** the headline is sent to the LLM, not marked processed without LLM call

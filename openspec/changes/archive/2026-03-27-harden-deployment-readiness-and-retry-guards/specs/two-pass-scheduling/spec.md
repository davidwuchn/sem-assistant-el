## MODIFIED Requirements

### Requirement: Pass 2 outputs scheduling decisions in simple format
Pass 2 SHALL output scheduling decisions in a simple line-based format, one line per task:
```
ID: <uuid> | SCHEDULED: <timestamp>
ID: <uuid> | (unscheduled)
```
Decision parsing MUST be deterministic and line-scoped: each decision line SHALL map exactly one task ID to exactly one scheduling outcome, and parsing MUST NOT scan neighboring lines to infer or merge outcomes.

#### Scenario: Pass 2 uses simple scheduling format
- **WHEN** Pass 2 generates scheduling decisions
- **THEN** each decision is on its own line
- **AND** format is `ID: <uuid> | SCHEDULED: <timestamp>` or `ID: <uuid> | (unscheduled)`
- **AND** task bodies are NOT included in Pass 2 output

#### Scenario: Mixed scheduled and unscheduled lines are parsed independently
- **WHEN** Pass 2 output contains adjacent `SCHEDULED` and `(unscheduled)` decision lines for different task IDs
- **THEN** each line maps only to the task ID present on that same line
- **AND** no scheduling outcome is inherited from or associated with another line

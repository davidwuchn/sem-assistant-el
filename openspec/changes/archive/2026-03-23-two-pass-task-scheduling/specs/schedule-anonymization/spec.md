## Purpose

This capability defines how existing tasks from tasks.org are anonymized for the Pass 2 planning prompt.

## ADDED Requirements

### Requirement: Anonymization format
When building the Pass 2 planning prompt, existing tasks.org tasks SHALL be anonymized to the format:
```
YYYY-MM-DD HH:MM-HH:MM busy PRIORITY:{A|B|C} TAG:{work|family|routine|opensource}
```

#### Scenario: Task anonymized correctly
- **WHEN** a task with SCHEDULED "2026-03-23 14:00-15:00", priority A, and tag :work: is anonymized
- **THEN** the output is `2026-03-23 14:00-15:00 busy PRIORITY:A TAG:work`

### Requirement: No titles, IDs, or descriptions included
The anonymized format SHALL NOT include task titles, IDs, or descriptions. Only time blocks with priority and filetag are included.

#### Scenario: Sensitive content excluded
- **WHEN** a task is anonymized
- **THEN** no task title, ID, or description appears in the output

### Requirement: Anonymized schedule used in Pass 2 prompt
The anonymized schedule SHALL be included in the Pass 2 planning prompt to provide context without exposing sensitive information.

#### Scenario: Anonymized schedule in prompt
- **WHEN** Pass 2 prompt is constructed
- **THEN** the anonymized existing schedule is included

### Requirement: Batch temp tasks anonymized for Pass 2
New tasks from the inbox batch (stored in temp file) SHALL be anonymized before being sent to Pass 2 LLM. The anonymized format is:
```
- ID: <uuid> | TAG:<tag> | SCHEDULED: <timestamp>
- ID: <uuid> | TAG:<tag> | (unscheduled)
```

#### Scenario: Temp task anonymized for Pass 2
- **WHEN** a batch temp task is anonymized for Pass 2
- **THEN** only ID, TAG, and existing SCHEDULED (if any) are included
- **AND** the full task body is NOT sent to the LLM
- **AND** sensitive content is never exposed to the LLM

#### Example: Anonymized temp task
- **WHEN** a task with ID `abc-123`, tag `:routine:`, and no existing SCHEDULED is anonymized
- **THEN** the output is `- ID: abc-123 | TAG:routine | (unscheduled)`

- **WHEN** a task with ID `def-456`, tag `:work:`, and SCHEDULED `<2026-03-20 09:00-10:00>` is anonymized
- **THEN** the output is `- ID: def-456 | TAG:work | SCHEDULED: <2026-03-20 09:00-10:00>`

### Requirement: Sensitive content never sent to LLM
The Pass 2 LLM SHALL never receive task bodies, descriptions, or any content that may contain sensitive information. Only anonymized metadata (ID, TAG, existing scheduling) is sent.

#### Scenario: Sensitive content excluded from Pass 2
- **WHEN** Pass 2 prompt is constructed with batch temp tasks
- **THEN** no task bodies, descriptions, or sensitive content appears in the prompt

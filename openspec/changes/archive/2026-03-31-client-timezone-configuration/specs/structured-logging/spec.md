## MODIFIED Requirements

### Requirement: Log entry field definitions
Each log entry SHALL use the following exact field format:
- `HH:MM:SS`: 24-hour local time in `CLIENT_TIMEZONE`
- `MODULE`: one of `core`, `router`, `rss`, `url-capture`, `security`, `llm`, `elfeed`, `purge`, `init`
- `EVENT-TYPE`: one of `INBOX-ITEM`, `URL-CAPTURE`, `RSS-DIGEST`, `ARXIV-DIGEST`, `ELFEED-UPDATE`, `PURGE`, `STARTUP`, `ERROR`
- `STATUS`: one of `OK`, `RETRY`, `DLQ`, `SKIP`, `FAIL`
- `tokens=NNN`: approximate input character count divided by 4 (integer, no decimals). Omitted if no LLM call was made.
- `message`: free-form string, no newlines, max 200 characters

#### Scenario: Module field valid
- **WHEN** a module logs an entry
- **THEN** the MODULE field is one of the allowed values

#### Scenario: Event-type field valid
- **WHEN** an event is logged
- **THEN** the EVENT-TYPE field is one of the allowed values

#### Scenario: Status field valid
- **WHEN** an event is logged
- **THEN** the STATUS field is one of the allowed values

#### Scenario: Tokens field included when LLM called
- **WHEN** an LLM call is made
- **THEN** `tokens=NNN` is included in the log entry

#### Scenario: Tokens field omitted when no LLM
- **WHEN** no LLM call is made
- **THEN** `tokens=` is omitted from the log entry

#### Scenario: Log timestamp uses client timezone
- **WHEN** `sem-core-log` formats `HH:MM:SS`
- **THEN** the time value reflects `CLIENT_TIMEZONE` local time

### Requirement: Log file structure
The system SHALL use the following exact structure for `/data/sem-log.org`, and date headings SHALL be partitioned by client-timezone day boundaries:

```
* YYYY
** YYYY-MM (Month Name)
*** YYYY-MM-DD Day
- [HH:MM:SS] [MODULE] [EVENT-TYPE] [STATUS] tokens=NNN | message
```

#### Scenario: Year heading created
- **WHEN** logging an entry
- **THEN** the `* YYYY` heading exists or is created

#### Scenario: Month heading created
- **WHEN** logging an entry
- **THEN** the `** YYYY-MM (Month Name)` heading exists or is created

#### Scenario: Day heading created
- **WHEN** logging an entry
- **THEN** the `*** YYYY-MM-DD Day` heading exists or is created

#### Scenario: Day rollover follows client timezone
- **WHEN** local midnight is crossed in `CLIENT_TIMEZONE`
- **THEN** subsequent entries are written under the new `*** YYYY-MM-DD` heading for that client-local date

## Purpose

This capability defines the structured logging system that records all module events to sem-log.org and errors to errors.org.

## Requirements

### Requirement: Structured logging to sem-log.org
All modules SHALL write structured log entries to `/data/sem-log.org` via `sem-core-log`. The file SHALL be valid Org-mode, readable directly in Orgzly.

#### Scenario: Log file created if absent
- **WHEN** `sem-core-log` is called and `/data/sem-log.org` does not exist
- **THEN** the file is created with proper Org structure

#### Scenario: Entries readable in Orgzly
- **WHEN** `/data/sem-log.org` is opened in Orgzly
- **THEN** it displays as a valid Org file with proper headings

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

#### Scenario: Day rollover follows client timezone
- **WHEN** local midnight is crossed in `CLIENT_TIMEZONE`
- **THEN** subsequent entries are written under the new `*** YYYY-MM-DD` heading for that client-local date

### Requirement: sem-core-log creates headings as needed
The `sem-core-log` function SHALL create `/data/sem-log.org` and all required heading levels if they do not exist. Each call SHALL append exactly one list item under the correct `*** YYYY-MM-DD` heading.

#### Scenario: File and headings auto-created
- **WHEN** `sem-core-log` is called and the file/headings don't exist
- **THEN** they are created automatically

#### Scenario: Single entry appended
- **WHEN** `sem-core-log` is called
- **THEN** exactly one list item is appended under the correct day heading

### Requirement: sem-core-log-error appends to errors.org
The `sem-core-log-error` function SHALL call `sem-core-log` with `STATUS=FAIL` or `STATUS=DLQ` AND append the raw error detail to `/data/errors.org` as an actionable Org TODO entry.

#### Scenario: Error logged to sem-log.org
- **WHEN** `sem-core-log-error` is called
- **THEN** an entry with `STATUS=FAIL` or `STATUS=DLQ` is written to `/data/sem-log.org`

#### Scenario: Error detail appended to errors.org
- **WHEN** `sem-core-log-error` is called
- **THEN** the raw error detail is appended to `/data/errors.org`

### Requirement: sem-core-log never raises errors
The `sem-core-log` function SHALL never raise an error itself. The function body SHALL be wrapped in `(cl-block sem-core-log ...)` to support `cl-return-from` calls. All file I/O SHALL be wrapped in `condition-case`. If writing to `/data/sem-log.org` fails, the function SHALL emit a stderr-visible fallback line via `(message "SEM-STDERR: ...")` and continue without crashing.

#### Scenario: Unwritable log file handled
- **WHEN** `/data/sem-log.org` is not writable
- **THEN** `sem-core-log` emits a `SEM-STDERR` fallback message and does not crash

#### Scenario: cl-return-from works correctly
- **WHEN** `sem-core-log` needs to return early due to unwritable log file
- **THEN** `(cl-return-from sem-core-log nil)` executes without error because the function body is wrapped in `cl-block`

#### Scenario: condition-case does not swallow cl-return-from errors
- **WHEN** the `condition-case` handler `(t nil)` is evaluated
- **THEN** it does not attempt to call `t` as a function because `cl-return-from` properly exits the `cl-block` instead of throwing

#### Scenario: Fallback path never raises secondary logging errors
- **WHEN** primary log file I/O fails and fallback emission is attempted
- **THEN** fallback handling does not propagate errors to callers

### Requirement: errors.org format
The `/data/errors.org` file SHALL support optional metadata in error headlines for severity and classification. `sem-core-log-error` callers MAY provide metadata containing `:priority` and `:tags`; when present, headline output SHALL include the provided priority token (for example `[#A]`) and Org tags (for example `:security:`) while preserving the existing error body format.

Malformed-sensitive security failures SHALL be written with priority `[#A]` and tag `:security:`.

The `/data/errors.org` file SHALL use the following format for each error entry:

```
* TODO [PRIORITY?] [YYYY-MM-DD HH:MM:SS] [MODULE] [EVENT-TYPE] FAIL :tags?:
DEADLINE: <YYYY-MM-DD Day HH:MM>
:PROPERTIES:
:CREATED: [YYYY-MM-DD HH:MM:SS]
:END:
Error: <error message string>

** Input
<original input text or URL that caused the failure>

** Raw LLM Output
<raw LLM response, or "N/A" if LLM was not called>
```

#### Scenario: Error entry created with actionable scheduling metadata
- **WHEN** an error is logged
- **THEN** a `TODO` headline is created with both `DEADLINE` and `:CREATED:` metadata

#### Scenario: Metadata priority and tags appear in error headline
- **WHEN** `sem-core-log-error` is called with metadata `:priority` and `:tags`
- **THEN** the created `errors.org` TODO headline includes the provided priority and tags

#### Scenario: Metadata omission preserves legacy formatting
- **WHEN** `sem-core-log-error` is called without metadata
- **THEN** the created `errors.org` entry uses the legacy headline format without added tags/priority

#### Scenario: Input preserved
- **WHEN** an error is logged
- **THEN** the original input is saved under `** Input`

#### Scenario: Raw LLM output preserved
- **WHEN** an error is logged
- **THEN** the raw LLM response is saved under `** Raw LLM Output`

#### Scenario: Orgzly sees new errors as overdue actionable items
- **WHEN** a new error is written to `/data/errors.org`
- **THEN** Org clients recognize it as a TODO with an already-due deadline

#### Scenario: Malformed-sensitive uses high-priority security classification
- **WHEN** malformed-sensitive preflight failure is logged
- **THEN** the error headline includes `[#A]` and `:security:`

### Requirement: errors.org is append-only
The `/data/errors.org` file SHALL be append-only. Entries SHALL never be deleted or modified by the daemon.

#### Scenario: Entries never deleted
- **WHEN** the daemon runs
- **THEN** existing entries in `/data/errors.org` are not removed

#### Scenario: Entries never modified
- **WHEN** the daemon runs
- **THEN** existing entries in `/data/errors.org` are not changed

### Requirement: sem-core-log-error is sole writer of errors.org
No module SHALL write to `/data/errors.org` directly. All error entries SHALL go through `sem-core-log-error`.

#### Scenario: Direct writes forbidden
- **WHEN** a module needs to log an error
- **THEN** it calls `sem-core-log-error`, not writing to `errors.org` directly

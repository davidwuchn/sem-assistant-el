# Specification: assertions

## Purpose

Define requirements for integration test assertions that validate outcomes.

## ADDED Requirements

### Requirement: Assertions validate test outcomes
The system SHALL run assertions after artifact collection to validate integration test results. All configured assertions MUST run even when some fail, and assertion coverage MUST include pre-existing TODO immutability checks, occupied-window overlap policy checks, trusted URL-capture output checks, and task prompt normalization behavior checks for shorthand inputs.

#### Scenario: All assertions run regardless of prior failures
- **WHEN** running assertions
- **THEN** all configured assertions MUST run even if one fails
- **AND** short-circuiting MUST NOT occur

#### Scenario: TODO count assertion
- **WHEN** running the TODO count assertion
- **THEN** `grep -c '^\* TODO ' tasks.org` MUST equal EXPECTED_TASK_COUNT
- **AND** if it fails, the message MUST be `FAIL: expected N TODO entries, got M` (where `N=EXPECTED_TASK_COUNT`)

#### Scenario: Keyword presence assertion
- **WHEN** running the keyword presence assertion
- **THEN** the script MUST grep for each headline title keyword defined in the `keywords` array in `tasks.org`
- **AND** each keyword MUST match
- **AND** if any keyword is missing, the failure message MUST name the missing keyword
- **AND** keyword fixtures MUST include shorthand/edge-case identifiers used for normalization coverage (for example `INC-7781` and `AMBIGUOUS-WEEKDAY-CASE-9012`)

#### Scenario: Scheduled time lower-bound and overlap policy assertion
- **WHEN** running scheduling policy assertions
- **THEN** each newly generated scheduled task MUST be strictly greater than `runtime_now + 1 hour`, except explicit fixed-schedule exception tasks
- **AND** assertion evaluation MAY apply a small tolerance window (for example 60 seconds) to account for minute-granularity Org timestamps vs second-granularity runtime anchors
- **AND** newly generated tasks MUST avoid overlaps with pre-existing occupied windows by default
- **AND** overlap checks MUST be skipped for explicit fixed-schedule exception tasks because they intentionally preserve fixture-authored timestamps
- **AND** overlaps with pre-existing occupied windows MUST be accepted only for explicit exception policy cases
- **AND** if a violation occurs, the failure message MUST identify the task and compared timestamps or conflicting window

#### Scenario: Fixed-schedule exception title matching is permissive
- **WHEN** matching generated task titles to fixed-schedule exception titles during assertions
- **THEN** matching MUST be case-insensitive
- **AND** Org priority markers (for example `[#A]`, `[#B]`, `[#C]`) MUST be ignored
- **AND** assertions MAY allow a bounded partial-title match to tolerate deterministic normalization differences
- **AND** for matched fixed-schedule exceptions, scheduled timestamp MUST match fixture schedule intent

#### Scenario: Date-only fixture accepts same-day normalized time range
- **WHEN** a fixed-schedule exception fixture timestamp is date-only (`<YYYY-MM-DD Day>`)
- **THEN** assertion matching MUST accept generated same-day timestamps that include explicit time ranges
- **AND** exact start/end minute equality is required only when fixture timestamp includes explicit time components

#### Scenario: Pre-existing TODO immutability assertion
- **WHEN** running pre-existing lifecycle assertions after a full run
- **THEN** pre-existing TODO entries MUST NOT be mutated, removed, reordered, or re-timestamped
- **AND** pre-existing TODOs without original `SCHEDULED` MUST remain unscheduled
- **AND** expected append-only addition of newly generated tasks MUST be allowed

#### Scenario: Org validity assertion
- **WHEN** running the Org validity assertion
- **THEN** the script MUST run:
  ```
  emacs --batch \
    --eval "(condition-case err \
              (progn (find-file \"RUN_DIR/tasks.org\") \
                     (org-mode) \
                     (org-element-parse-buffer) \
                     (message \"ORG-VALID\")) \
            (error (error \"ORG-INVALID: %s\" err)))"
  ```
- **AND** exit code 0 indicates valid
- **AND** non-zero indicates invalid with message `FAIL: tasks.org is not valid Org`

#### Scenario: Sensitive content restoration assertion
- **WHEN** running the sensitive content restoration assertion
- **THEN** the script MUST grep for each sensitive keyword defined in the `sensitive_keywords` array in tasks.org
- **AND** each keyword MUST be present in the output (proving sensitive content was unmasked)
- **AND** if any keyword is missing, the failure message MUST name the missing keyword

#### Scenario: URL-capture trusted output assertion
- **WHEN** running trusted URL-capture assertions
- **THEN** at least one new captured org-roam node MUST contain required org-roam headers (`:PROPERTIES:`, `:ID:`, `#+title:`)
- **AND** the same node MUST contain exact trusted URL in `#+ROAM_REFS`
- **AND** the same node MUST contain exact `Source: [[URL][URL]]` in `* Summary`
- **AND** the same node MUST include a link to `[[id:96a58b04-1f58-47c9-993f-551994939252][...]]`
- **AND** defanged URL forms (`hxxp://`, `hxxps://`) MUST NOT appear in validated trusted-URL candidate nodes

#### Scenario: Shorthand normalization fixtures are asserted
- **WHEN** running normalization behavior assertions for mobile-style shorthand fixtures
- **THEN** assertions MUST validate title cleanup and body preservation outcomes for representative noisy inputs
- **AND** assertions MUST include ambiguous weekday and misspelling fixtures (for example, `wendsday`) with deterministic expected behavior

#### Scenario: Priority extraction and defaulting are asserted
- **WHEN** running normalization behavior assertions
- **THEN** assertions MUST verify urgency cues map to expected priority tokens
- **AND** assertions MUST verify fallback priority `[#C]` when urgency cues are absent
- **AND** assertions MUST verify deterministic precedence for conflicting urgency markers

#### Scenario: Schedule parsing and duration defaulting are asserted
- **WHEN** running normalization behavior assertions
- **THEN** assertions MUST verify clear relative time phrases produce expected schedule hints
- **AND** assertions MUST verify ambiguous timing inputs are accepted as unscheduled
- **AND** assertions MUST verify default 30-minute duration behavior when schedule time exists without explicit duration

#### Scenario: Final exit code reflects assertion results
- **WHEN** all assertions have completed
- **THEN** the script MUST exit with code 0 if all assertions passed
- **AND** exit with code 1 if any assertion failed, including URL-capture assertion failures

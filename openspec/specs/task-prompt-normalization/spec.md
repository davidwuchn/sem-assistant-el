# Specification: task-prompt-normalization

## Purpose

Define the Pass 1 normalization contract so noisy mobile captures are transformed into deterministic, structured Org TODO entries with preserved context.

## Requirements

### Requirement: Pass 1 prompt defines explicit normalization contract
The Pass 1 task prompt SHALL define an explicit normalization contract that transforms raw mobile capture text into a structured Org TODO output with cleaned title, useful body content, mandatory priority, and best-effort scheduling hints.

#### Scenario: Prompt states transform objective
- **WHEN** the Pass 1 prompt is assembled for a `:task:` headline
- **THEN** it explicitly instructs the model to transform raw capture text into a complete structured TODO entry
- **AND** it requires normalized title and body content rather than format-only rewriting

#### Scenario: Prompt allows multi-line body preservation
- **WHEN** input note content includes multiple semantic lines
- **THEN** the prompt allows multi-line normalized body output
- **AND** body normalization preserves meaningful identifiers and context from the input

### Requirement: Pass 1 prompt includes example-driven shorthand parsing rules
The Pass 1 task prompt SHALL include concrete examples for interpreting shorthand and noisy capture phrases, including relative date phrases, weekday variants, duration hints, and noisy urgency markers.

#### Scenario: Relative date examples are included
- **WHEN** the prompt is rendered
- **THEN** it includes examples for relative phrases such as `tomorrow`, `next week`, and weekday names
- **AND** examples describe expected normalized output behavior

#### Scenario: Noisy text examples are included
- **WHEN** the prompt is rendered
- **THEN** it includes examples for noisy inputs such as repeated punctuation, abbreviations, and misspellings
- **AND** examples preserve non-scheduling identifiers like phone numbers and ticket IDs in content

### Requirement: Normalization defines deterministic edge-case behavior
The Pass 1 normalization contract SHALL define deterministic handling for ambiguous weekday references, locale spelling variations, missing explicit dates, and identifier-preservation edge cases.

#### Scenario: Ambiguous weekday stays unscheduled
- **WHEN** input includes weekday-only intent that cannot be resolved to one clear date/time
- **THEN** normalized output remains valid without `SCHEDULED`

#### Scenario: Known weekday misspelling is normalized
- **WHEN** input uses a common weekday misspelling such as `wendsday`
- **THEN** normalization treats it as the intended weekday for schedule inference
- **AND** falls back to unscheduled output if confidence remains low

#### Scenario: Identifiers are preserved verbatim
- **WHEN** input contains phone numbers, ticket IDs, or similar identifiers
- **THEN** normalization preserves those identifiers in title/body content
- **AND** identifiers are not dropped or altered during cleanup

### Requirement: Runtime datetime context anchors relative interpretation
The Pass 1 prompt SHALL include runtime current datetime context so relative phrases are interpreted deterministically for that run.

#### Scenario: Runtime datetime included in prompt context
- **WHEN** Pass 1 prompt context is prepared
- **THEN** current datetime is included as an explicit reference value
- **AND** relative phrases are interpreted against that value

#### Scenario: Deterministic behavior across equivalent inputs
- **WHEN** the same shorthand input is processed with the same runtime datetime context
- **THEN** Pass 1 interpretation remains consistent for relative date/time extraction

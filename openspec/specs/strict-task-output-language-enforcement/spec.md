# Specification: strict-task-output-language-enforcement

## Purpose

Ensure Pass 1 `:task:` transformation output uses one deterministic output language for all generated natural-language content.

## Requirements

### Requirement: Pass 1 task output language is mandatory
For `:task:` transformation, the system SHALL generate all natural-language task content in the configured output language.

#### Scenario: Configured language is enforced
- **WHEN** `OUTPUT_LANGUAGE` is set to a non-empty value
- **THEN** Pass 1 generated task title and body text SHALL be produced entirely in that language

### Requirement: English is the fallback output language
If no output language is configured, Pass 1 `:task:` transformation SHALL default to English for all generated natural-language task content.

#### Scenario: Unset language uses English
- **WHEN** `OUTPUT_LANGUAGE` is unset or empty at task transformation time
- **THEN** Pass 1 generated task title and body text SHALL be in English

### Requirement: Mixed-language generated task content is rejected
Pass 1 task transformation SHALL NOT emit mixed-language generated content for task title/body within a single transformed task output.

#### Scenario: Source text contains multiple languages
- **WHEN** raw task input contains multilingual or code-switched text
- **THEN** the generated task title/body output SHALL still be entirely in the selected output language

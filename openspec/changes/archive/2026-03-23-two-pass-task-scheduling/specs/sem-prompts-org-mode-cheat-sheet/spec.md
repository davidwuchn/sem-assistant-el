# Sem Prompts Org Mode Cheat Sheet

## Purpose

This capability provides a comprehensive org-mode syntax cheat sheet for LLM system prompts.

## MODIFIED Requirements

### Requirement: Cheat sheet includes SCHEDULED time range format
The cheat sheet SHALL include the SCHEDULED time range format `SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>` in addition to the basic date-only format.

#### Scenario: Basic SCHEDULED format
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include `SCHEDULED: <YYYY-MM-DD Day>` format

#### Scenario: SCHEDULED time range format
- **WHEN** the cheat sheet is used in an LLM prompt
- **THEN** it SHALL include `SCHEDULED: <YYYY-MM-DD HH:MM-HH:MM>` format for time ranges
- **AND** it SHALL note that Pass 2 may use single time format `SCHEDULED: <YYYY-MM-DD HH:MM>` or `DEADLINE: <YYYY-MM-DD HH:MM>`

### Requirement: All existing cheat sheet content preserved
The cheat sheet SHALL continue to cover all previously specified org-mode syntax elements: headings, text formatting, code blocks, block elements, lists, tables, links, Orgzly URI schemes, BAD/GOOD callouts, and output wrapping rules.

#### Scenario: All existing content preserved
- **WHEN** the cheat sheet is updated
- **THEN** all existing requirements from the original spec are still satisfied

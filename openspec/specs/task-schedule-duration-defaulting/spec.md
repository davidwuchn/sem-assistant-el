# Specification: task-schedule-duration-defaulting

## Purpose

Define best-effort schedule extraction and deterministic default duration behavior before planner processing.

## Requirements

### Requirement: Schedule extraction remains best effort
Pass 1 SHALL treat schedule extraction as best effort and MAY return tasks without `SCHEDULED` when timing intent is ambiguous.

#### Scenario: Ambiguous timing yields unscheduled output
- **WHEN** input timing intent is too ambiguous to map confidently
- **THEN** Pass 1 returns a valid TODO without a `SCHEDULED` timestamp

#### Scenario: Explicit timing yields scheduled hint
- **WHEN** input contains clear date/time intent
- **THEN** Pass 1 returns a `SCHEDULED` hint in supported timestamp format

### Requirement: Missing duration defaults to 30 minutes
When Pass 1 produces a schedule time without explicit duration, the normalization flow SHALL apply a default 30-minute duration block before planner processing.

#### Scenario: Scheduled time without duration gets 30-minute block
- **WHEN** Pass 1 output includes a start time and no explicit duration
- **THEN** downstream normalization assigns a 30-minute duration for planner input

#### Scenario: Explicit duration is preserved
- **WHEN** Pass 1 output includes both start time and explicit duration intent
- **THEN** the explicit duration is preserved
- **AND** the 30-minute default is not applied

### Requirement: Default duration handling is transparent to planner authority
Default duration injection SHALL not change the two-pass authority model; planner remains responsible for final schedule placement.

#### Scenario: Planner may still move defaulted schedule
- **WHEN** a task reaches planning with a defaulted 30-minute duration
- **THEN** planner may adjust final timestamp according to scheduling policy

## Why

Mobile inbox capture currently depends on implicit LLM interpretation of shorthand notes (for example: `2morrow`, `important!!`, partial time hints, and noisy titles). This causes inconsistent Pass 1 normalization quality and weak downstream planning signals because priority and scheduling intent are not extracted with a strict, example-driven contract.
The task flow needs a clearer prompt policy that converts raw notes into deterministic, high-quality TODO entries while still allowing planner fallback behavior when scheduling certainty is low.

## What Changes

- Expand Pass 1 task system prompt with explicit normalization policy, ordered priority semantics (`[#A] > [#B] > [#C]`), and many concrete parsing examples for shorthand date/time/duration phrases.
- Add explicit Pass 1 rules for urgency extraction (for example, `important!!`, `urgent`, `ASAP`) to priority, while allowing priority omission from raw LLM output and enforcing `[#C]` defaulting when priority is missing.
- Add explicit Pass 1 rules for schedule extraction from natural language phrases (`tomorrow`, `next week`, weekday names, "before X", "for an hour", "few hours").
- Include runtime current date/time in Pass 1 prompt context so relative date phrases are anchored deterministically.
- Keep schedule optional at validation level: Pass 1 may return unscheduled tasks when confidence is low, and planner remains responsible for final placement.
- Define a normalization fallback rule: if Pass 1 returns a schedule time without explicit duration, apply a default 30-minute duration before planner step.
- Strengthen prompt intent from "format this task" to "transform raw capture note into a complete, structured TODO with cleaned title, useful body content (multi-line allowed when input is multi-line), priority, and best-effort scheduling hint".
- Extend integration coverage with additional mobile-style shorthand and noisy-input examples to validate extraction behavior and fallback invariants.
- Edge cases to define explicitly in specs/tests: ambiguous weekday references, locale spelling variations (for example `wendsday`), missing explicit date, conflicting urgency markers, and notes containing phone numbers or identifiers that must stay in content.
- Out of scope: replacing Pass 2 planning policy, introducing external calendar integration, changing allowed `:FILETAGS:` set, or implementing non-LLM deterministic NLP parser.

## Capabilities

### New Capabilities

- `task-prompt-normalization`: Pass 1 prompt provides explicit normalization/extraction rules and examples to transform shorthand mobile notes into structured TODOs with best-effort schedule hints and optional LLM priority (with downstream fallback to `[#C]` when missing).
- `task-priority-defaulting`: Normalization flow guarantees final task priority by applying deterministic fallback to `[#C]` when LLM priority is absent.
- `task-schedule-duration-defaulting`: When Pass 1 produces a schedule without explicit duration, default duration handling applies 30-minute blocks.

### Modified Capabilities

- `task-llm-pipeline`: Prompt contract expands to include runtime datetime context, stronger note-to-TODO transformation expectations, and explicit extraction examples for shorthand language.
- `two-pass-scheduling`: Pass 1 schedule remains optional and planner remains authoritative for unscheduled tasks and final scheduling decisions.
- `assertions`: Integration assertions expand with shorthand-note fixtures and checks for priority extraction, schedule parsing behavior, and fallback handling.

## Impact

Task capture quality improves for fast mobile notes by making Pass 1 extraction behavior explicit, example-driven, and testable. Priority becomes consistently available for planning decisions, scheduling hints become more usable, and planner fallback behavior remains safe when Pass 1 cannot infer confident timing.

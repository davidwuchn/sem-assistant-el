## Context

The daemon currently evaluates time in multiple ways: some paths rely on container-local wall clock,
others force UTC formatting, and some implicit date rollovers come from Emacs defaults. This mixed
model creates incorrect task scheduling and date boundaries whenever the VPS timezone differs from the
client's intended timezone.

This change introduces one authoritative runtime timezone from `.env` (`CLIENT_TIMEZONE`) and applies
it consistently across cron execution context, runtime datetime injected into LLM prompts, Org
timestamp parsing and generation, purge windows, RSS digest day labels, and daily log partitioning.

Constraints from proposal:
- Startup must fail fast if `CLIENT_TIMEZONE` is missing or invalid.
- No per-user/per-task timezone override support.
- Existing stored Org timestamps are not migrated.

## Goals / Non-Goals

**Goals:**
- Make all scheduling-critical behavior deterministic against `CLIENT_TIMEZONE`.
- Remove UTC-forced wording/semantics when configured timezone is non-UTC.
- Ensure cron-triggered workflows execute at client wall-clock times.
- Align date-based outputs (digests/logs/purge window) to client calendar day boundaries.

**Non-Goals:**
- Backfilling or rewriting historical Org timestamps.
- Adding timezone fields to Org entries or per-item overrides.
- Introducing custom daylight-saving rules beyond IANA timezone data.
- Building manual timezone conversion tooling for operators.

## Decisions

1. Introduce a single timezone access boundary in runtime code.
   - Decision: add one shared helper in core startup/runtime path that reads and validates
     `CLIENT_TIMEZONE`, then exposes it to modules that need "now", date formatting, or timezone-aware
     comparisons.
   - Why: centralizing retrieval/validation avoids subtle drift from repeated ad hoc `getenv` use.
   - Alternative considered: each module reads `.env` directly and validates independently.
     Rejected because it duplicates logic and increases inconsistency risk.

2. Validate timezone at startup and fail fast.
   - Decision: daemon initialization verifies `CLIENT_TIMEZONE` is present and corresponds to a valid
     IANA zone available in the container's tzdata/Emacs runtime. Invalid values stop startup.
   - Why: misconfiguration should be detected immediately, not after partial processing.
   - Alternative considered: fallback to UTC or container local timezone.
     Rejected because fallback silently violates explicit user intent.

3. Enforce timezone-consistent "now" and timestamp normalization in scheduling flows.
   - Decision: inbox processing and two-pass scheduling compute runtime bounds and generated Org
     timestamps from client-timezone "now", and keep parsing/comparison in the same timezone context.
   - Why: mixed-zone comparisons are the root cause of off-by-hours/day behavior.
   - Alternative considered: keep UTC internal model and convert only at output boundaries.
     Rejected for now due to larger refactor scope and current proposal requirement for
     configured-timezone semantics end-to-end.

4. Align cron execution semantics with client wall-clock time.
   - Decision: run cron jobs with timezone environment set from `CLIENT_TIMEZONE` so crontab schedules
     are interpreted in that zone.
   - Why: this is required for expected trigger times without host timezone coupling.
   - Alternative considered: keep host cron timezone and shift schedule expressions manually.
     Rejected because expression shifts are brittle across DST transitions.

5. Treat date-partitioned outputs as client-day artifacts.
   - Decision: purge window checks (4AM), RSS digest date naming, and daily logs use client timezone day
     boundaries.
   - Why: these features are day-sensitive and must align to user calendar, not server geography.
   - Alternative considered: retain UTC for logs/digests while changing scheduler only.
     Rejected because it creates operational confusion and mixed temporal semantics.

6. Update prompt/runtime wording to avoid UTC implication.
   - Decision: prompt context and diagnostics include client-local datetime representation and timezone
     identifier, avoiding "UTC" labels unless timezone is actually UTC.
   - Why: model planning quality depends on accurate temporal context framing.
   - Alternative considered: keep UTC labels and rely on hidden conversion.
     Rejected because it increases ambiguity and user-visible mismatch.

## Risks / Trade-offs

- [Incomplete module adoption] -> Mitigation: inventory all "now"/date formatting call sites and add
  regression tests for each modified capability.
- [Container/runtime timezone data mismatch] -> Mitigation: validate with known zone IDs at startup and
  document tzdata requirement in deployment docs.
- [DST boundary edge cases] -> Mitigation: add tests around DST transitions for schedule comparisons and
  day rollover-sensitive features.
- [Behavior change for existing deployments] -> Mitigation: explicit release note and docs update that
  `CLIENT_TIMEZONE` is mandatory and authoritative.
- [Cron implementation variance between environments] -> Mitigation: enforce timezone via environment in
  the managed cron setup and verify with integration-safe smoke checks.

## Migration Plan

1. Add and validate mandatory `CLIENT_TIMEZONE` during daemon startup.
2. Refactor time acquisition/normalization helpers to use client timezone.
3. Apply helper usage across cron-sensitive and scheduling-sensitive modules.
4. Update docs and `.env` contract to require valid IANA timezone values.
5. Add/adjust tests for prompt context, scheduling bounds, purge window, digest date, and log rollover.
6. Deploy with `CLIENT_TIMEZONE` configured; rollback by reverting code change if severe issue occurs
   (no data migration required).

## Open Questions

- Should startup validation reject `Etc/*` zones that invert offset sign conventions, or allow all valid
  IANA identifiers?
- Should logs include both client-local and UTC timestamps for operator troubleshooting, while preserving
  client-day partitioning?

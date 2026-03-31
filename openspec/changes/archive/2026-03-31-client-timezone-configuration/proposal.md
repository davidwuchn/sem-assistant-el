## Why

The daemon currently mixes container-local time and UTC-forced time in scheduling-critical logic. This creates incorrect dates and times for users whose personal timezone differs from VPS/container timezone.

The service must schedule tasks, deadlines, and cron-triggered workflows according to the client timezone declared in configuration, not server location.

## What Changes

Introduce a single static timezone configuration sourced from `.env` as `CLIENT_TIMEZONE` (IANA timezone name, for example `Europe/Belgrade`).

Define `CLIENT_TIMEZONE` as the authoritative timezone for all runtime time semantics used by Org timestamp generation, schedule/deadline interpretation, and cron schedule execution context.

Replace UTC-forced scheduling semantics with configured-timezone semantics in prompts, planning bounds, timestamp normalization, and time-window checks.

Add strict startup validation for `CLIENT_TIMEZONE` to fail fast on missing/invalid timezone values.

## Capabilities

### New Capabilities

- `client-timezone-configuration`: The system accepts exactly one static client timezone from `CLIENT_TIMEZONE` and applies it consistently across daemon runtime. Constraint: value must be a valid IANA timezone identifier. Constraint: invalid or empty value causes startup failure. Constraint: no per-user or per-task timezone overrides.

### Modified Capabilities

- `cron-scheduling`: Cron schedule interpretation is based on configured client timezone rather than VPS default/container implicit timezone. Constraint: all cron jobs in `crontab` execute according to `CLIENT_TIMEZONE` wall-clock times.
- `inbox-processing`: Pass 1 runtime datetime context provided to LLM is expressed in configured client timezone, not UTC-forced notation. Constraint: wording and formatting must not imply UTC when configured timezone is non-UTC.
- `two-pass-scheduling`: Pass 2 runtime bounds, timestamp parsing, overlap checks, and schedule insertion use configured client timezone semantics. Constraint: comparisons and generated Org timestamps must be timezone-consistent end-to-end.
- `inbox-purge`: Time-window guard (4AM purge window) is evaluated in configured client timezone. Constraint: purge must not trigger at 4AM VPS-local time when client timezone differs.
- `rss-digest`: Daily digest date labels and output file date derivation use configured client timezone calendar day. Constraint: day rollover follows client timezone.
- `structured-logging`: Daily message log partitioning date is aligned to configured client timezone day boundary. Constraint: rollover must not be UTC-forced.
- `documentation-path-contract`: Configuration documentation is updated to require `CLIENT_TIMEZONE`, define accepted format, and state its system-wide effect on scheduling/time interpretation.

## Impact

Eliminates timezone drift between user intent and daemon behavior when VPS timezone differs from client timezone.

Prevents incorrect scheduling outcomes caused by mixed UTC/local semantics in Org timestamp handling.

Explicit scope boundaries:
- In scope: static `CLIENT_TIMEZONE` config, startup validation, runtime timezone application, cron timezone alignment, prompt/runtime-bound wording updates, and tests/docs updates for timezone semantics.
- Out of scope: migration of existing tasks/timestamps, per-user timezone support, daylight-saving policy customization beyond IANA rules, manual timezone conversion utilities, and any implementation of timezone fields in Org entries.

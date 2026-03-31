## 1. Startup timezone contract

- [x] 1.1 Add a shared timezone helper that reads `CLIENT_TIMEZONE` and validates it as an available IANA zone.
- [x] 1.2 Wire startup to fail fast with a clear configuration error when `CLIENT_TIMEZONE` is missing or invalid.
- [x] 1.3 Add/adjust ERT tests covering startup success, missing value failure, and invalid value failure.

## 2. Runtime scheduling timezone semantics

- [x] 2.1 Update cron setup so daemon schedules are interpreted in `CLIENT_TIMEZONE` instead of host/container defaults.
- [x] 2.2 Refactor Pass 1/Pass 2 time context so `runtime_now` and `runtime_min_start` are computed in `CLIENT_TIMEZONE`.
- [x] 2.3 Update LLM prompt runtime datetime labels/content to avoid implying UTC when `CLIENT_TIMEZONE` is non-UTC.
- [x] 2.4 Add/adjust tests for timezone-aware scheduling bounds and prompt timezone wording.

## 3. Client-day boundary outputs

- [x] 3.1 Update inbox purge window evaluation to use `CLIENT_TIMEZONE` 4:00 AM semantics.
- [x] 3.2 Update RSS digest date path generation to use client-local calendar day and ensure `sem-llm-request` is used for digest LLM calls.
- [x] 3.3 Update structured log timestamp and day-heading rollover to follow `CLIENT_TIMEZONE` local day boundaries.
- [x] 3.4 Add/adjust tests for purge timing, digest file date rollover, and daily log partitioning across local midnight.

## 4. Documentation and rollout checks

- [x] 4.1 Update configuration documentation to mark `CLIENT_TIMEZONE` as required and document valid IANA examples.
- [x] 4.2 Document system-wide timezone effects (cron timing, scheduling, purge window, digest date labels, log rollover).
- [x] 4.3 Run targeted ERT tests and `sh dev/elisplint.sh` on touched Elisp files, fixing any regressions before apply.

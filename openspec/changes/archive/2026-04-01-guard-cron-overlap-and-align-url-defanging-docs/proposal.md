## Why

The runtime currently depends on cron-triggered `emacsclient` jobs that can overlap when a prior run takes longer than the schedule interval, which can create duplicate processing and race-prone file mutations. In parallel, repository documentation and runtime behavior are misaligned on URL defanging, which creates operator confusion and incorrect expectations during incident review.

## What Changes

- Define and enforce a single overlap policy for cron-triggered jobs so only one active execution per guarded job is allowed at a time.
- Require deterministic overlap outcomes: skip-or-serialize behavior must be explicit, observable, and consistent across restarts.
- Define guard behavior for edge cases: stale lock artifacts, process crash while holding lock, clock skew effects on lock age checks, and watchdog/restart interactions.
- Define scope boundaries for guarding so long-running jobs and high-frequency jobs are both covered without introducing deadlock between independent jobs.
- Align repository documentation with actual runtime behavior for URL defanging and `sem-security-sanitize-urls` usage.
- Resolve mismatch by selecting one authoritative behavior and making all affected docs and behavior statements consistent with that contract.
- Make non-goals explicit: no changes to trust boundary model, no new log storage tier, no changes to sensitive-content tokenization semantics, and no expansion to multi-user tenancy requirements.

## Capabilities

### New Capabilities

- `cron-overlap-guard-policy`: Cron-triggered SEM jobs execute under a defined non-overlap contract with explicit handling for stale locks, crash recovery, and duplicate-trigger suppression; behavior is observable in existing operational logs.

### Modified Capabilities

- `url-defanging-contract`: URL defanging expectations are explicitly defined and documentation is synchronized with actual runtime behavior for task/RSS/url-capture outputs and `sem-security-sanitize-urls` call-site intent.

## Impact

Reduces duplicate-processing and race-condition risk in normal operations, increases predictability during daemon restarts, and removes operator ambiguity caused by documentation/runtime drift. This change is constrained to execution policy and behavioral contract clarity; it does not introduce new product surface area or alter the single-user trusted WebDAV deployment model.

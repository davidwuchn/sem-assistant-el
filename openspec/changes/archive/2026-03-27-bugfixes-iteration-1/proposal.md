## Why

Current runtime behavior has four correctness/reliability defects that can cause data races, avoidable runtime errors, duplicated log output, and unsafe command execution patterns. These defects are in active execution paths and should be fixed together as one bounded bugfix iteration.

## What Changes

- Enforce mutex usage for async task temp-file writes in `sem-router`.
- Fix the debug logging expression in `sem-router--parse-headlines` that currently uses a marker where a number is required.
- Add hash-based tracking in `sem-core--flush-messages-daily` to prevent repeated duplicate appends of unchanged `*Messages*` content.
- Replace shell-string command execution in `sem-git-sync--run-command` with argv-based process execution.
- Scope boundary: this change only addresses these four defects.
- Out of scope: scheduler behavior changes, prompt/schema changes, cron changes, WebDAV behavior, integration test workflow changes, and new features.

## Capabilities

### New Capabilities

- `messages-flush-hash-dedup`: Flush logic skips appending when `*Messages*` content hash is unchanged since the last successful flush; date rollover behavior must still work.

### Modified Capabilities

- `router-task-temp-write-serialization`: Task temp-file writes in async callbacks must execute through the existing write mutex path; lock contention behavior and retry semantics must remain deterministic.
- `router-parse-debug-safety`: Headline parsing debug logging must never call numeric operators with marker objects; debug path must be non-fatal.
- `git-sync-command-execution-safety`: Git sync command runner must execute commands via argv-based process APIs instead of shell command strings; output/exit-code reporting behavior must remain equivalent for callers.

## Impact

- Reduces risk of concurrent write corruption in task temp output.
- Removes a known parse-path runtime error source in debug logging.
- Prevents repeated growth from duplicate message-log appends when content has not changed.
- Improves command execution safety and reliability by eliminating shell-string parsing in git sync runner.
- No intended user-facing feature changes; this is a reliability/safety bugfix-only iteration.

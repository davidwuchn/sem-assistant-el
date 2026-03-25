## 1. Watchdog Runtime Script

- [x] 1.1 Add `dev/sem-daemon-watchdog` with probe, timeout, startup-grace, and restart-trigger flow using `emacsclient -s sem-server`.
- [x] 1.2 Add lock-based serialization (for example via `flock`) so overlapping cron invocations exit cleanly with a logged skip.
- [x] 1.3 Implement idempotent keepalive termination and structured logging for probe success, probe timeout/failure, grace-period suppression, lock contention, and restart action.

## 2. Container Wiring and Scheduling

- [x] 2.1 Update `crontab` to include `*/15 * * * *\troot\t/usr/local/bin/sem-daemon-watchdog` while keeping existing business jobs on their own cron entries.
- [x] 2.2 Update `Dockerfile.emacs` to copy the watchdog script into `/usr/local/bin/sem-daemon-watchdog` and mark it executable.

## 3. Configuration and Safety Defaults

- [x] 3.1 Add configurable defaults for watchdog interval-compatible runtime settings (probe timeout and startup grace) via environment variables with safe fallbacks.
- [x] 3.2 Ensure watchdog behavior is deterministic outside startup grace (failed or timed-out probe triggers restart path) and no-op safe if the keepalive process is already absent.

## 4. Validation and Documentation

- [x] 4.1 Add/extend automated tests to cover watchdog success, timeout failure, grace suppression, lock contention skip, and idempotent restart behavior.
- [x] 4.2 Validate cron schedule completeness against spec expectations and document watchdog operational scope and troubleshooting notes in project docs.

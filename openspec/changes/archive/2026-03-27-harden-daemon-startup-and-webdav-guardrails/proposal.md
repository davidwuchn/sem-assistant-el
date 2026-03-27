## Why

- Pass 2 planning can fail with an explicit non-success outcome, while already-generated Pass 1 tasks remain in temp files and can later be deleted by stale-temp cleanup, causing task loss.
- Daemon process liveness and workflow readiness are currently conflated: startup can fail partially while probes still report success, leaving the service "up" but non-functional.
- The container entrypoint can keep running even when daemon startup failed, masking failures and delaying recovery.
- WebDAV credential defaults permit weak accidental production configuration (`changeme`), which is unsafe for internet-exposed personal deployments.

## What Changes

- Define fail-safe behavior so planning non-success paths preserve generated tasks instead of allowing drop-on-cleanup outcomes.
- Introduce a lightweight SEM readiness probe contract that verifies critical startup state and dependency load status (without heavy workflow execution).
- Align watchdog and container startup health checks to the same SEM readiness probe contract.
- Add production-only WebDAV password guardrails with strict fast-fail validation requirements.
- Preserve integration-test flow compatibility by excluding test-mode/runtime from production password guardrail enforcement.

## Capabilities

### New Capabilities

- `daemon-readiness-probe`: Expose a lightweight SEM function that returns deterministic ready/not-ready state based on successful module/dependency initialization; no heavy processing, no external network calls, and safe for frequent probe invocation.
- `production-webdav-password-policy`: Enforce production-only startup validation requiring password length >= 20 and inclusion of at least one lowercase letter, one uppercase letter, and one digit; fail fast on violation before serving WebDAV.

### Modified Capabilities

- `pass2-planning-failure-handling`: On explicit planning non-success, use Pass 1 fallback semantics to prevent task loss from temp-file cleanup; guarantee generated tasks are either persisted or explicitly surfaced as failed without silent drop.
- `watchdog-health-check`: Replace pure liveness probing with SEM readiness probing so watchdog restart behavior reflects functional readiness, not just daemon process existence.
- `startup-entrypoint-health-gate`: Gate keepalive/tail behavior on SEM readiness success so startup failures are visible and container state reflects actual service availability.

## Impact

- Reliability improves by removing a known silent task-loss path during planning failures.
- Operational observability improves because health checks now represent functional readiness.
- Startup failure handling becomes fail-fast and recoverable instead of silently masked.
- Security posture improves for personal internet-exposed usage by preventing weak production WebDAV passwords by default.
- Out of scope: changing task scheduling logic quality, adding new cron jobs, adding remote secret managers, or redesigning integration test architecture beyond preserving compatibility with current test flows.

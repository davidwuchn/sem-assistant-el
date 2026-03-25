## Why

The daemon can become unresponsive while the container still appears up because the foreground `tail -F` process keeps PID 1 alive. In that state, scheduled `emacsclient` jobs fail until manual intervention. A lightweight watchdog that forces a container restart on confirmed daemon unresponsiveness addresses the most common failure mode with minimal complexity.

## What Changes

- Add an external daemon liveness watchdog that pings Emacs on a fixed cadence (10-20 minutes) and triggers container restart recovery when the daemon does not respond.
- Define strict failure detection behavior to avoid ambiguous restart decisions (probe timeout, failure criteria, startup grace period, and probe overlap handling).
- Define explicit restart trigger behavior centered on terminating the foreground keepalive process so compose restart policy re-creates the container.
- Define non-goals to prevent scope creep into orchestration redesign or deep self-healing logic.

## Capabilities

### New Capabilities

- `daemon-liveness-watchdog`: The system detects daemon unresponsiveness using periodic `emacsclient` probes and forces container restart by terminating the keepalive process. Constraints: probe cadence MUST be within 10-20 minutes; each probe MUST have a hard timeout; startup grace period MUST prevent immediate restart during normal boot; watchdog executions MUST be serialized to avoid concurrent restart attempts; restart action MUST be idempotent if the target process is already gone; detection/restart events MUST be observable in logs.

### Modified Capabilities

- `cron-scheduling`: The cron schedule is extended with a watchdog job dedicated to daemon liveness supervision; this watchdog is operational-only and MUST NOT execute business workflows (inbox processing, purge, RSS, git sync).

## Impact

- Reliability: Automatically recovers from the "daemon down, container up" state and is expected to resolve most operational hangs without operator action.
- Safety: No changes to note-processing semantics or data formats; only liveness supervision and restart triggering are added.
- Operational constraints: Short unavailability windows during forced restarts are expected; repeated failures may cause restart loops if root cause persists.
- Out of scope: Root-cause diagnosis, automatic dependency remediation, partial in-container process supervision beyond restart trigger, migration to external orchestrators/systemd/k8s, and any change to task-routing or LLM behavior.

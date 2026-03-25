## Context

The project runs an Emacs daemon in a Docker container where PID 1 is a
foreground `tail -F` keepalive command. This keeps the container marked
healthy from Docker's perspective even when the daemon itself is unresponsive.
Current scheduled jobs use `emacsclient`; when the daemon hangs, these jobs
fail repeatedly until an operator manually restarts the container.

The proposal defines a narrow operational fix: add a watchdog that probes
daemon responsiveness on a 10-20 minute cadence and forces container recovery
by terminating the keepalive process when unresponsiveness is confirmed. The
change must avoid interference with business workflows and keep restart actions
safe under repeated or overlapping runs.

## Goals / Non-Goals

**Goals:**
- Detect daemon unresponsiveness using periodic `emacsclient` probes with a hard timeout.
- Prevent false-positive restarts during normal boot with a startup grace period.
- Ensure watchdog executions are serialized so concurrent runs cannot race restarts.
- Trigger container recreation by terminating the keepalive process in an idempotent way.
- Emit clear logs for probe outcomes and restart decisions.

**Non-Goals:**
- Diagnose root causes of daemon hangs.
- Add deep in-container process supervision beyond watchdog probe + restart trigger.
- Redesign orchestration (systemd/Kubernetes/external supervisor migration).
- Modify inbox routing, RSS, purge, git sync, or LLM behavior.

## Decisions

1. Use a dedicated watchdog script invoked by cron, separate from application jobs.
   - Why: isolates operational liveness logic from business workflows and aligns
     with the modified `cron-scheduling` capability.
   - Alternative considered: embedding watchdog checks inside existing cron jobs.
     Rejected because it couples unrelated workflows and can suppress watchdog
     checks when business jobs are disabled or delayed.

2. Probe liveness with `emacsclient` plus a hard timeout.
   - Why: `emacsclient` is the real dependency for scheduled work, so probing it
     directly validates service usability rather than container process state.
   - Alternative considered: Docker healthcheck based only on process presence.
     Rejected because it cannot detect "daemon down, container up" failures.

3. Use explicit failure criteria with startup grace.
   - Decision: one timed-out or failed probe after grace triggers recovery,
     while startup grace suppresses restart actions until normal daemon boot is
     expected to complete.
   - Why: keeps behavior deterministic and simple while avoiding immediate
     restart loops during initial container start.
   - Alternative considered: require multiple consecutive failures before
     restart. Rejected for now to reduce recovery delay and complexity.

4. Serialize watchdog runs with a lock file and `flock`-style semantics.
   - Why: cron can overlap when a probe hangs near the next schedule window;
     serialization prevents duplicate restart attempts and noisy logs.
   - Alternative considered: relying on short probe timeout only.
     Rejected because timeout does not fully eliminate overlap risk.

5. Restart by terminating the keepalive foreground process.
   - Why: this is the minimal action that activates existing compose restart
     policy without introducing new orchestration dependencies.
   - Alternative considered: `docker compose restart` from inside the
     container. Rejected due to additional tooling/permission requirements and
     tighter coupling to host Docker control plane.

## Risks / Trade-offs

- [False positive due to transient slowdown] -> Use a bounded probe timeout,
  startup grace, and structured logs so operators can tune cadence/timeout.
- [Restart loop when root cause persists] -> Keep restart trigger deterministic,
  surface repeated failures in logs, and document operator intervention path.
- [Lock file stale state] -> Use process-bound locking (`flock`) instead of
  sentinel-only files; process exit releases lock automatically.
- [Short service interruption during restart] -> Accept as operational trade-off
  for automatic recovery from hung daemon state.

## Migration Plan

1. Add watchdog script and wiring to the container image/runtime.
2. Add dedicated cron entry at configured 10-20 minute cadence.
3. Configure startup grace duration and probe timeout via env/config defaults.
4. Deploy and observe logs to confirm probe, skip-during-grace, and restart
   paths behave as expected.
5. Rollback by removing/disabling watchdog cron entry and script invocation,
   restoring prior behavior without data migration.

## Open Questions

- What exact default cadence and timeout values should ship initially (for
  example 15m cadence, 30-60s timeout)?
- Should restart triggering require one failure or N consecutive failures in
  production once telemetry is available?
- Which log sink should watchdog events use to match existing operator
  troubleshooting workflow most effectively?

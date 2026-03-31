## Context

This change fixes four production reliability and correctness gaps in the daemon:

1. Error records in `/data/errors.org` are currently passive notes and do not trigger Orgzly overdue notifications.
2. Security token expansion detection exists but is not enforced in the router LLM callback path.
3. Logging file I/O failures can silently drop operational telemetry.
4. Inbox/cursor hash identity uses delimiter-based concatenation that can collide for different inputs.

The implementation must preserve daemon resilience (never crash on logging/security errors), avoid new external dependencies, and keep behavior compatible with existing cron/docker operational flow.

## Goals / Non-Goals

**Goals:**
- Make new `errors.org` entries actionable in Orgzly by writing TODO + DEADLINE metadata.
- Enforce runtime sensitive-token expansion detection in the task routing callback and reject unsafe output.
- Ensure logging failures are externally visible through stderr-compatible fallback output.
- Make headline hash identity collision-safe and deterministic across parser and purge paths.
- Keep changes localized to existing Elisp modules and specs.

**Non-Goals:**
- Introducing new monitoring/alerting systems beyond existing Orgzly + container logs.
- Retrofitting historical `errors.org` entries.
- Adding broader LLM output sanitization beyond token expansion detection.
- Changing deployment topology, cron cadence, or adding new runtime services.

## Decisions

### 1) Errors become overdue TODO items in `errors.org`

- **Decision:** Update `sem-core-log-error` to emit Org headlines with `TODO` and a `DEADLINE` timestamp set to the error timestamp.
- **Why:** Orgzly already syncs this file and treats overdue TODO items as actionable notifications, enabling alerts without external systems.
- **Alternatives considered:**
  - Keep plain headlines and add a separate notification daemon: rejected as additional complexity/infrastructure.
  - Use scheduled timestamps without TODO keyword: rejected because actionable task semantics are less consistent across clients.

### 2) Enforce security verification in router callback before restoration

- **Decision:** In `sem-router--route-to-task-llm` callback, run `sem-security-verify-tokens-present` on the raw LLM response before restoration/validation. If `expanded` is non-empty, reject output, log CRITICAL via `sem-core-log-error`, and mark headline processed.
- **Why:** The security check is designed for tokenized output and must run before restoration to detect leakage of original sensitive content.
- **Alternatives considered:**
  - Check only after restoration: rejected because restored output can hide whether leakage originated from token expansion.
  - Retry same item indefinitely: rejected due to risk of repeated sensitive leakage and retry loops.

### 3) Logging fallback to stderr-safe message path

- **Decision:** When primary log/error file writes fail, emit a fallback `(message "SEM-STDERR: ...")` line in guarded error handling so the daemon continues.
- **Why:** Container stderr/log capture provides a no-cost observability backstop when file logging fails.
- **Alternatives considered:**
  - Re-signal logging errors: rejected because daemon stability is a core invariant.
  - Silent ignore: rejected because it masks operational failures.

### 4) Replace delimiter hashes with structured JSON encoding

- **Decision:** Replace `(concat title "|" tags "|" body)` with `(json-encode (vector title tags-str body))` before `secure-hash` in both router parsing and inbox purge.
- **Why:** Structured encoding removes delimiter ambiguity and collision class created by embedded separators.
- **Alternatives considered:**
  - Escape delimiter characters manually: rejected as fragile and easy to diverge across modules.
  - Use a different custom delimiter: rejected because any delimiter scheme has similar ambiguity risks.

### 5) Accept one-time cursor invalidation after hash migration

- **Decision:** Do not perform a cursor migration step; allow first run after deployment to reprocess inbox entries under new hash scheme.
- **Why:** Simpler and lower risk than in-place migration logic; existing processing paths are intended to be idempotent and resilient.
- **Alternatives considered:**
  - Build migration utility for legacy hashes: rejected as complexity with limited value.

## Risks / Trade-offs

- [One-time inbox reprocessing spike] -> Mitigation: rely on idempotent handling (duplicate-to-DLQ / existing URL dedupe) and monitor first run logs.
- [False-positive user concern from overdue error TODOs] -> Mitigation: document that new error entries are intentionally overdue to force visibility.
- [Fallback logging path failure recursion] -> Mitigation: keep fallback wrapped in defensive error handling and avoid additional file I/O in fallback path.
- [Behavioral drift if hash formula differs across modules] -> Mitigation: update specs and tests to assert identical formula usage in router and purge implementations.

## Migration Plan

1. Implement code changes in `sem-core.el`, `sem-router.el`, and hash consumers in purge logic.
2. Update affected specs (`structured-logging`, `security-masking`, `inbox-processing`, `inbox-purge`) to encode required behavior.
3. Add/adjust ERT coverage for:
   - TODO + DEADLINE formatting for new errors.
   - Token expansion detection rejection path in router callback.
   - stderr fallback visibility on forced log write failure.
   - Hash parity and collision-safety expectations.
4. Deploy normally (no cron/container changes).
5. Verify first post-deploy run for expected one-time reprocessing and absence of daemon crashes.

Rollback strategy:
- Revert the change commit(s) if critical regressions occur.
- Accept that entries written during the rollout window may use mixed formats; both are readable.

## Open Questions

- Should CRITICAL security rejection entries include a dedicated machine-parseable marker/tag for easier downstream triage?
- Should we add a lightweight startup warning if legacy cursor hashes are detected, to set operator expectations for first-run reprocessing?

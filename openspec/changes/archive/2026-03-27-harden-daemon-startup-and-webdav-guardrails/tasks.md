## 1. Add deterministic readiness probe in Elisp

- [x] 1.1 Identify mandatory startup invariants and define a single `ready/not-ready` contract in the daemon code path.
- [x] 1.2 Implement a lightweight readiness probe function that checks only local process state (no network, no workflow execution).
- [x] 1.3 Add ERT coverage for readiness success and failure cases when invariants are missing.

## 2. Move watchdog health decisions to readiness

- [x] 2.1 Update watchdog probe logic to execute the readiness probe instead of process-liveness checks.
- [x] 2.2 Preserve bounded watchdog cadence and enforce probe timeout handling as a failed probe outcome.
- [x] 2.3 Add tests that verify restart/health decisions are driven by readiness results and timeout failures.

## 3. Gate container handoff on readiness success

- [x] 3.1 Update startup entrypoint polling to wait for readiness success before entering keepalive/tail behavior.
- [x] 3.2 Implement fail-fast startup exit when readiness polling exceeds the configured attempt window.
- [x] 3.3 Add script-level validation/tests to confirm keepalive never starts on readiness timeout.

## 4. Enforce production-only WebDAV password guardrails

- [x] 4.1 Add startup validation for production mode requiring `WEBDAV_PASSWORD` length >= 20 with lowercase, uppercase, and digit.
- [x] 4.2 Ensure non-production and integration-test runtime paths bypass this password policy.
- [x] 4.3 Add/adjust tests for weak-password rejection, strong-password acceptance, and explicit remediation logging.

## 5. Preserve Pass 1 tasks on explicit Pass 2 non-success

- [x] 5.1 Update planning fallback flow so explicit Pass 2 non-success preserves Pass 1 generated tasks for deterministic handling.
- [x] 5.2 Ensure temp-file cleanup runs only after tasks are persisted or an explicit failed outcome is recorded.
- [x] 5.3 Add regression tests proving non-success no longer causes silent task loss via temp cleanup.

## 6. Verify change-level completion

- [x] 6.1 Run targeted ERT tests for router/core/startup/WebDAV behavior touched by this change.
- [x] 6.2 Run full project test suite and fix any regressions introduced by startup hardening.

## 1. Production WebDAV Deployment Hardening

- [x] 1.1 Replace production WebDAV service implementation with Apache `httpd` + `mod_dav` HTTPS setup compatible with `/certs/live/<domain>/` mounts
- [x] 1.2 Enforce production startup validation for required WebDAV auth and certificate-backed TLS configuration with actionable failure logging
- [x] 1.3 Enforce production-only WebDAV password policy (length/complexity) while preserving non-production and integration-test exemptions
- [x] 1.4 Update production bootstrap/deployment docs to require certificate issuance/readability checks before secure WebDAV startup and use only policy-compliant credential examples

## 2. Model Tier Runtime Wiring

- [x] 2.1 Pass optional `OPENROUTER_WEAK_MODEL` through container/runtime environment into the daemon process
- [x] 2.2 Ensure weak-tier model resolution uses `OPENROUTER_WEAK_MODEL` when non-empty and falls back to `OPENROUTER_MODEL` when unset or empty
- [x] 2.3 Add or update tests covering configured, unset, and empty weak-tier model scenarios

## 3. Bounded Task API Retry and DLQ Routing

- [x] 3.1 Implement API-failure retry-state increment exactly once per failed attempt in task processing
- [x] 3.2 Enforce configured retry cap for API failures so exhausted tasks stop retrying and transition to terminal handling
- [x] 3.3 Route tasks with exhausted API-failure retries to DLQ with terminal failure status logging
- [x] 3.4 Preserve malformed-output handling as a distinct non-API-failure path and verify it does not increment API-failure retry state

## 4. Deterministic Pass-2 Scheduling Parsing

- [x] 4.1 Refactor pass-2 decision parsing to process output line-by-line with one task ID and one outcome per line
- [x] 4.2 Ensure mixed adjacent `SCHEDULED` and `(unscheduled)` lines are parsed independently without cross-line outcome inheritance
- [x] 4.3 Add parser tests for mixed-format planner outputs and unknown/non-decision lines

## 5. Readiness Invariant Gating and Verification

- [x] 5.1 Gate readiness success on required startup dependency-load invariants and force not-ready on logged dependency-load failures
- [x] 5.2 Ensure readiness probe result remains deterministic for current process state and independent of external network reachability
- [x] 5.3 Add or update startup/readiness tests for healthy initialization, missing invariants, and dependency-load-failure cases

## 6. Change-Level Validation

- [x] 6.1 Run focused ERT tests for touched modules and fix regressions
- [x] 6.2 Run full suite `eask test ert app/elisp/tests/sem-test-runner.el` and address failures
- [x] 6.3 Verify documentation and runtime behavior alignment for production WebDAV, retry/DLQ flow, parser determinism, and readiness semantics

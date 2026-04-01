## Context

Sensitive-block handling is a cross-cutting safety boundary used by both task routing
(`sem-router.el`) and URL capture (`sem-url-capture.el`) before content is sent to
the LLM wrapper (`sem-llm.el`). The prior approach tolerated malformed blocks in some
cases and depended on a post-response verification step to detect possible leakage.
That verification happened too late to provide fail-closed guarantees because the LLM
request could already have been made.

The change must ensure malformed sensitive delimiters are rejected before any LLM call,
and that failures are clearly represented as security incidents in operational logs.
It also must preserve legitimate flexibility where users type delimiters in uppercase
or mixed case.

## Goals / Non-Goals

**Goals:**
- Enforce strict preflight validation for sensitive delimiters before every LLM call.
- Route malformed-sensitive inputs to terminal DLQ behavior with no retry.
- Keep marker detection case-insensitive while requiring delimiters to be standalone lines.
- Record malformed-sensitive failures in `errors.org` as high-priority security incidents.
- Remove post-response token-presence verification and replace it with stronger preflight tests.

**Non-Goals:**
- Changing provider/model selection or any `sem-llm` request contract unrelated to security preflight.
- Reworking non-sensitive parsing/routing policies.
- Changing general scheduling, purge, or git-sync behavior.
- Introducing a new physical DLQ file format; this change continues using existing retry/error evidence.

## Decisions

### 1) Fail before LLM request on malformed delimiters
Decision: make `sem-security-tokenize-sensitive` authoritative for delimiter validity and raise
explicit errors for malformed patterns (missing end marker, end without begin, inline marker,
nested blocks).

Rationale: the tokenizer is the only shared pre-LLM choke point for both routing flows, so this
gives a single fail-closed contract.

Alternatives considered:
- Keep permissive tokenization and rely on post-response checks: rejected, too late.
- Add duplicated validators in each caller: rejected, higher drift risk and weaker consistency.

### 2) Treat malformed-sensitive as terminal, not retryable
Decision: when sanitize/tokenize raises malformed-sensitive errors, classify as terminal security
failure (`security-malformed`) and route directly to DLQ semantics (no retry path).

Rationale: malformed delimiters are deterministic input problems, not transient infra failures.
Retries do not improve correctness and create noise.

Alternatives considered:
- Keep existing retry behavior: rejected, could repeatedly re-send unsafe input attempts.
- Drop silently: rejected, loses auditability.

### 3) Mark security failures with explicit metadata
Decision: extend `sem-core-log-error` metadata support so callers can add `:priority` and `:tags`
(used as `[#A]` and `:security:` for malformed-sensitive cases).

Rationale: security incidents should be highly visible and queryable in `errors.org`.

Alternatives considered:
- Encode severity inside free-form error text only: rejected, weak structure for assertions/search.

### 4) Remove post-response token verification
Decision: delete token-expansion post-response verification logic and associated tests.

Rationale: once strict preflight forbids malformed delimiters before LLM calls, post-response
checks are redundant complexity that do not strengthen boundary guarantees.

Alternatives considered:
- Keep both preflight and post-response checks: rejected, higher maintenance for little risk reduction.

### 5) Align integration assertions with terminal malformed fixture
Decision: add malformed-sensitive fixture + assertion proving it is excluded from `tasks.org`,
logged as security/high-priority, and reflected in DLQ/security evidence.

Rationale: unit tests prove function-level behavior; integration assertions prove system-level
contract and regressions across scripts/artifacts.

Alternatives considered:
- Unit tests only: rejected, misses pipeline-level contract drift.

## Risks / Trade-offs

- [Stricter parser may reject previously tolerated notes] -> Mitigation: clear error messages,
  security-tagged `errors.org` entries, and tests for accepted case-insensitive delimiters.
- [Cross-module behavior drift between router and URL capture] -> Mitigation: enforce shared
  tokenizer contract and add dedicated tests in both modules.
- [Operator confusion about DLQ evidence location] -> Mitigation: integration assertion validates
  expected evidence in `errors.org` and `sem-log.org` and documents no dedicated DLQ file.
- [Future marker syntax changes could bypass strict checks] -> Mitigation: centralize marker
  parsing in `sem-security.el` and require corresponding spec/test updates for syntax changes.

## Migration Plan

1. Ship strict tokenizer changes in `sem-security.el` and remove post-response verification paths.
2. Update router and URL-capture error handling to classify malformed-sensitive as terminal.
3. Extend `sem-core-log-error` metadata formatting and apply security metadata at call sites.
4. Update unit tests for strict malformed/case-insensitive behavior and no-LLM preflight failure.
5. Update integration fixture and assertions for malformed-sensitive handling.
6. Validate with unit tests (`eask test ert app/elisp/tests/sem-test-runner.el`) and delimiter lint
   checks (`sh dev/elisplint.sh ...`).
7. Human operator runs integration script manually and confirms assertion results.

Rollback strategy:
- Revert this change set in git to restore prior permissive behavior if needed.
- No data migration is required because this change affects runtime validation and logging paths only.

## Open Questions

- Should we add a dedicated `failure-kind` convention document for all terminal security classes,
  or keep this localized to malformed-sensitive handling for now?
- Do we want a future dedicated DLQ artifact file for security incidents, or continue deriving DLQ
  evidence from retry/processed state and logs?

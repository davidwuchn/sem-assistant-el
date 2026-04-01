## Why

Sensitive content must never be sent to external LLM providers when users rely on `#+begin_sensitive`/`#+end_sensitive` markers. Current behavior allows ambiguity around malformed blocks and includes post-response verification that does not provide fail-closed guarantees. The system needs strict pre-LLM validation, deterministic DLQ routing, and stronger tests to keep this safety boundary reliable.

## What Changes

- Enforce fail-closed sensitive tokenization before any LLM request in task and URL-capture flows.
- Treat malformed sensitive markers as terminal security failures routed to DLQ with no retry.
- Accept case-insensitive sensitive delimiters while keeping standalone-line delimiter rules strict.
- Remove post-response token expansion verification logic and dead tests tied to that behavior.
- Extend unit and integration tests for malformed delimiter corner cases and DLQ/assertion contracts.
- Update error entry formatting so malformed sensitive-block failures are marked `[#A]` and tagged `:security:`.
- Explicitly out of scope: changing LLM provider selection, scheduling policy semantics, non-sensitive parsing rules, and unrelated WebDAV/git-sync behavior.

## Capabilities

### New Capabilities

- `strict-sensitive-preflight-dlq`: Detect malformed sensitive blocks before LLM calls and route items to DLQ without retry.
- `security-priority-error-marking`: Record malformed-sensitive security failures in `errors.org` as `[#A]` with `:security:` tags.
- `integration-security-dlq-assertions`: Validate malformed-sensitive integration fixture handling, including task count invariants and DLQ presence assertions.

### Modified Capabilities

- `task-routing-tokenization`: Sensitive tokenization becomes strict fail-closed, case-insensitive for delimiters, and standalone-line constrained.
- `url-capture-tokenization`: URL-capture sensitive tokenization adopts the same strict malformed-block handling contract as task routing.
- `security-tokenization-tests`: Remove dead post-response verification tests and replace with strict parser/tokenization corner-case coverage.

## Impact

This change reduces secret leakage risk by eliminating ambiguous fallback behavior and enforcing pre-LLM safety gates. Some previously tolerated malformed notes will now be rejected into DLQ, increasing explicit error volume while improving security guarantees. Test and assertion updates will increase confidence that strict sensitive-block handling remains stable across regressions.

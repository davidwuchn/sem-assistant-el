## Why

The LLM prompt instructs the model to produce a "brief one-line description" which causes it to summarize away `<<SENSITIVE_N>>` tokens entirely. The integration test reveals that sensitive content (`supersecret123`, `sk-live-abc123xyz789`) is not restored in tasks.org because the LLM output contains neither the tokens nor the original content.

Additionally, the current sanitizer lacks positional tracking — it replaces entire sensitive blocks but provides no semantic mapping of where each token should appear in the rewritten text.

## What Changes

1. **Prompt Engineering**: Update the LLM system prompt in `sem-router.el` to explicitly instruct the model to preserve `<<SENSITIVE_N>>` tokens verbatim and in the same logical/semantic position as the original content.

2. **Enhanced Sanitizer**: Extend `sem-security.el` with position-aware sensitive block tracking. Each block should carry metadata about its semantic location in the parent text, not just be globally replaced.

3. **Unit Tests**: Add round-trip tests that verify semantic position preservation, not just token presence.

## Capabilities

### Modified Capabilities

- `sem-router--route-to-task-llm` (prompt construction): Add explicit token-preservation instructions and BEFORE/AFTER examples showing semantic position preservation.

- `sem-security-sanitize-for-llm`: Enhance to track per-block position metadata for semantic restoration.

### New Capabilities

- `sem-security--detect-sensitive-blocks-with-position`: Enhanced detection that records the semantic position of each block for later restoration verification.

### Edge Cases

- **Token Expansion (CRITICAL)**: If the LLM outputs actual secret content (not a token), this indicates a CRITICAL BUG in the sanitizer — the secret reached the LLM. The response must be rejected and treated as a security incident. The sanitizer must be audited.

- **Multi-block Position Preservation**: When a body contains multiple sensitive blocks (`<<SENSITIVE_1>>`, `<<SENSITIVE_2>>`), ALL tokens must be preserved verbatim in the LLM output at their respective semantic positions.

- **Semantic Position Requirement**: Tokens must appear at the same logical location in the output as the original sensitive content appeared in the input. If input says "update password to `<<SENSITIVE_1>>`", output must have "update password to `<<SENSITIVE_1>>`" — not "update credentials" (rewritten without token).

- **Token-Verification Pre-Write**: Before writing LLM output to tasks.org, verify that all expected tokens are present and have not been expanded. If expansion is detected, reject the response.

- **Unit Test Compatibility**: Existing unit tests in `sem-security-test.el` must continue to pass after any changes.

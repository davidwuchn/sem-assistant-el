## Context

The sensitive content restoration flow has two components: masking (before LLM call) and unmasking (after LLM response). The masking works correctly — `#+begin_sensitive` blocks are replaced with `<<SENSITIVE_N>>` tokens. However, the unmasking produces empty results because the LLM summarizes away the tokens when generating a "brief one-line description."

The current flow in `sem-router--route-to-task-llm`:
1. Headline body is extracted and sanitized via `sem-security-sanitize-for-llm`
2. Tokenized body is injected into the LLM prompt
3. LLM generates a brief description (tokens lost)
4. `sem-security-restore-from-llm` runs on the LLM output — but tokens are absent, so nothing to restore

## Goals / Non-Goals

**Goals:**
- LLM preserves `<<SENSITIVE_N>>` tokens verbatim in output
- Tokens appear at the same semantic position as the original sensitive content
- Pre-write verification detects token expansion (actual secret in output)
- Existing unit tests continue to pass

**Non-Goals:**
- Re-architecting the LLM interaction layer
- Adding retry logic for token preservation failures (reject and log is sufficient)
- Changing the sanitizer's core tokenization algorithm

## Decisions

### Decision 1: Prompt Enhancement (vs. Pre/post-processing)

**Choice:** Update the LLM system prompt with explicit token-preservation instructions and BEFORE/AFTER examples.

**Rationale:** The root cause is that the LLM doesn't know tokens must be preserved. The fix should be at the source — instructing the model correctly. Pre/post-processing hooks would add complexity and still require the model to cooperate.

**Alternatives considered:**
- Pre-process LLM output to inject tokens back based on position metadata — too complex, fragile
- Use a separate LLM call to restore tokens — expensive, adds latency

### Decision 2: Position Tracking in Sanitizer (vs. Simple Tokenization)

**Choice:** Enhance `sem-security-sanitize-for-llm` directly to return per-block position metadata alongside the tokenized text and blocks-alist.

**Rationale:** To verify semantic position preservation, we need to know where each sensitive block was in the original text. A simple find-and-replace alist is insufficient — we need semantic anchors (e.g., "block 1 appeared after 'Password:'").

**Implementation approach:**
- `sem-security--detect-sensitive-blocks` enhanced to capture surrounding context (e.g., 20 chars before/after) per block
- `sem-security-sanitize-for-llm` returns a three-element list: `(tokenized-text . blocks-alist . position-info-alist)`
- Position info alist format: `((token . (before-context . after-context)) ...)`

**Alternatives considered:**
- Add new `sem-security-sanitize-for-llm-with-position` function — rejected, proposal says enhance existing function
- Character offset tracking — too brittle, context shifts during LLM rewriting
- Semantic role labeling — overkill, context strings are sufficient for verification

### Decision 3: Pre-Write Token Verification

**Choice:** Before writing LLM output to tasks.org, verify all expected tokens are present. If any token is missing (not expanded, not lost), accept. If expansion is detected (token replaced with secret), reject.

**Implementation approach:**
- `sem-security-verify-tokens-present(llm-output expected-tokens)` → returns `((missing . ()) (expanded . ()))`
- If `expanded` is non-empty, log CRITICAL error and reject response (do not write to tasks.org)
- Missing tokens (LLM just didn't use them) are acceptable

**Note on expansion detection:** We detect expansion by checking if the LLM output contains any actual secret content (from the blocks-alist). If the blocks-alist content appears in the output, a token was expanded.

### Decision 4: BEFORE/AFTER Example Format

**Choice:** Include a concrete example in the prompt showing:
- BEFORE: `#+begin_sensitive\nPassword: supersecret123\n#+end_sensitive`
- AFTER: `Password: <<SENSITIVE_1>>`

**Rationale:** Concrete examples are more effective than verbal instructions for token preservation. The example should use abstract secret names to avoid any possibility of the LLM learning actual secrets.

## Risks / Trade-offs

**[Risk] LLM still ignores tokens despite instructions** → Mitigation: Reject at pre-write verification. The task goes to DLQ. Human reviews the failure.

**[Risk] Position metadata increases sanitizer complexity** → Mitigation: Enhance existing `sem-security-sanitize-for-llm` signature; existing unit tests updated to handle new return structure.

**[Risk] Unit test compatibility** → Mitigation: Existing `sem-security-test-tokenize-detokenize-roundtrip` updated to handle new three-element return. New position-preservation tests added alongside.

**[Risk] Secret reaches LLM (CRITICAL)** → This indicates sanitizer bug. When expansion is detected, audit `sem-security--detect-sensitive-blocks` regex. Do not silently accept. Reject and alert.

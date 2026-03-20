## Context

The `sem-security--detokenize` function currently restores sensitive content by re-wrapping it in `#begin_sensitive` / `#end_sensitive` block markers. This behavior was inherited from an earlier design where markers served a dual purpose: indicating original sensitive block boundaries and preserving restoration metadata.

However, after sensitive content is restored, it is written directly to `tasks.org` and will **not** be re-sent to the LLM. The markers therefore serve no downstream purpose. Their presence causes formatting misalignment when LLM output is inserted into Org documents, degrading readability.

The change applies only to the **restoration** phase. The **tokenization** phase remains unchanged — sensitive blocks are still detected, replaced with tokens, and tracked in `blocks-alist`.

## Goals / Non-Goals

**Goals:**
- Restore sensitive content as plain text (no block markers)
- Preserve original content exactly (single-line or multi-line format)
- Maintain correct indentation for multi-line content (2 spaces per line, matching original block indentation)
- Add leading and trailing newlines for multi-line content to integrate cleanly into Org document flow
- Update affected unit tests to reflect new restoration behavior

**Non-Goals:**
- Modifying the tokenization phase (detection, token replacement, `blocks-alist` population)
- Changing URL sanitization behavior (unrelated to sensitive content restoration)
- Changing how secrets are stored or tracked internally
- Modifying `org-roam` or `elfeed` integrations

## Decisions

### Decision 1: Plain text restoration instead of marker-wrapped restoration

**Choice:** Restore sensitive content directly as plain text, without `#begin_sensitive` / `#end_sensitive` markers.

**Rationale:** The markers served a historical purpose during LLM interaction, but after restoration the content is written to `tasks.org` and never re-sent to the LLM. The markers add no value and cause formatting issues.

**Alternatives considered:**
- *Keep markers but make them invisible*: Would require CSS or Org markup changes affecting display only. Does not solve the structural misalignment issue when LLM output is inserted.
- *Remove markers at write time only*: Adds a second transformation pass. More complex than changing restoration behavior directly.

### Decision 2: Multi-line content formatting

**Choice:** For multi-line sensitive content, indent each line by 2 spaces and prepend/append a single newline.

**Format:**
```
\n
  line 1 content
  line 2 content
\n
```

**Rationale:** The 2-space indentation matches the indentation of the original `#begin_sensitive` block within the Org headline body. Adding leading/trailing newlines ensures the restored content sits on its own lines rather than running into adjacent text, preserving Org paragraph structure.

**Alternatives considered:**
- *No indentation*: Multi-line content would be flush-left, which looks inconsistent with surrounding Org content.
- *4-space indentation*: Would over-indent relative to typical Org body content.
- *Only leading newline, no trailing*: Trailing newline ensures following text starts on a fresh line.

### Decision 3: Single-line content formatting

**Choice:** Single-line content is placed at the exact token position, verbatim (no added newlines or indentation).

**Rationale:** A single token replacement preserves the original text position in the sentence. Adding newlines would break sentence continuity.

### Decision 4: Unit test updates only for affected tests

**Choice:** Only modify tests that verify restoration behavior. Do not modify tests that verify tokenization, URL sanitization, or expansion detection.

**Rationale:** The proposal identifies 3 tests that must be updated (`sem-security-test-tokenize-detokenize-roundtrip`, `sem-security-test-position-roundtrip`, `sem-router-test-security-block-round-trip`). Tests unrelated to restoration are unaffected.

### Decision 5: Clear blocks-alist after restoration

**Choice:** Clear `blocks-alist` after sensitive content has been successfully restored and written to `tasks.org`.

**Rationale:** The sensitive content has been written to the Org file. No further audit need is served by keeping the mapping in memory. Clearing it reduces memory footprint and prevents stale data.

### Decision 6: Documentation updates

**Choice:** Update `README.md` and architecture/design docs to reflect plain text restoration behavior.

**Rationale:** Documentation should reflect current behavior so future developers understand the sensitive content handling pipeline.

## Risks / Trade-offs

[Risk] Existing integrations that parse `#begin_sensitive` markers in `tasks.org` will break
→ Mitigation: This change is explicitly scoped to `sensitive-content-plaintext-restore`. Any consumer relying on markers should be updated separately. The change proposal covers this.

[Risk] Multi-line indentation may not match all Org document styles
→ Mitigation: 2-space indentation is a convention already used in the codebase. The proposal references "matching original block indentation" which implies the indentation was derived from the block's position in the document.

## Migration Plan

1. **Modify `sem-security--detokenize`**: Update restoration logic to output plain text per formatting decisions above.
2. **Clear `blocks-alist`**: Add cleanup after successful restoration/write.
3. **Run unit tests**: Execute `emacs --batch --load app/elisp/tests/sem-test-runner.el` to verify affected tests pass.
4. **Update unit tests**: Modify the 3 identified roundtrip tests to expect plain text restoration.
5. **Update documentation**: Update `README.md` and architecture/design docs to reflect plain text restoration behavior.
6. **Update integration test inbox**: Add multi-line sensitive block to `dev/integration/testing-resources/inbox-tasks.org`.
7. **Update integration test assertions**: Add negative marker assertion and order verification to `dev/integration/run-integration-tests.sh`.
8. **Human runs integration tests**: Agent does not execute integration tests. Human runs `bash dev/integration/run-integration-tests.sh` and provides results.
9. **Final verification**: Agent confirms all tests pass before marking implementation complete.

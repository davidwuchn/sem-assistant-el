## Context

This change addresses four distinct issues in the SEM Assistant codebase:

1. **Reasoning model noise**: Reasoning models (qwen3.5, etc.) include thinking traces in LLM responses, causing noisy error logs. The gptel backend needs configuration to suppress these traces.

2. **Obsolete macro warnings**: Emacs 31.1 deprecated `when-let` in favor of `when-let*`. Two occurrences in `sem-rss.el` cause compiler warnings.

3. **Spec/code mismatches**: Several specs reference outdated token formats or ambiguous requirements that don't match the actual code behavior.

4. **Insufficient integration test coverage**: Current integration tests don't verify sensitive block restoration or cron/emacsclient execution.

## Goals / Non-Goals

**Goals:**
- Eliminate reasoning model thinking trace noise from logs
- Remove Emacs 31.1 deprecation warnings for `when-let`
- Align specs with actual code behavior
- Add integration test coverage for sensitive content and cron verification

**Non-Goals:**
- GitHub sync improvements (out of scope)
- URL sanitization for org-roam output (intentionally excluded per code)
- Changes to actual task processing logic (only spec/code sync)
- Integration test execution by agent (human-only)

## Decisions

### Decision 1: Reasoning exclusion via gptel backend request-params

**Choice**: Add `:request-params '(:reasoning (:exclude t))` to the OpenRouter gptel backend configuration in `init.el`.

**Rationale**: Reasoning models like qwen3.5 send thinking traces as part of the response content. The gptel library supports passing model-specific parameters via `:request-params`. Setting `(:reasoning (:exclude t))` instructs the model to omit thinking traces from the response, reducing noise.

**Alternatives considered**:
- Post-process LLM responses to strip thinking traces: Rejected because it requires parsing model-specific output format and may incorrectly strip legitimate content.
- Use non-reasoning models only: Rejected because reasoning models provide better quality for complex tasks.

**Implementation**: Modify `sem-init--configure-gptel` in `init.el` to include the request-params in the backend definition.

---

### Decision 2: Replace `when-let` with `when-let*`

**Choice**: Change `when-let` to `when-let*` at lines 21 and 27 in `sem-rss.el`.

**Rationale**: `when-let*` is the Emacs 31.1 replacement for the obsolete `when-let`. The semantic difference is that `when-let*` binds sequentially (like `let*`), while old `when-let` bound in parallel (like `let`). In these specific cases (lines 21 and 27), the bindings are independent so sequential binding produces identical behavior.

**Alternatives considered**:
- Suppress warnings with `defvaralias` or warning suppression: Rejected because it doesn't fix the root cause.
- Restructure with nested `when` forms: Rejected because `when-let*` is the idiomatic replacement.

**Implementation**: Direct replacement of `when-let` with `when-let*` in both defconst initializers.

---

### Decision 3: Token format spec update from `{{SEC_ID_xxx}}` to `<<SENSITIVE_xxx>>`

**Choice**: Update `security-masking/spec.md` to document `<<SENSITIVE_xxx>>` as the token format.

**Rationale**: The code in `sem-security.el` uses `<<SENSITIVE_xxx>>` format (defined by `sem-security-token-prefix` and `sem-security-token-suffix`). The spec incorrectly documented `{{SEC_ID_xxx}}`. Since the code is correct and working, the spec must be updated to match.

**Alternatives considered**:
- Change code to match spec: Rejected because `<<SENSITIVE_xxx>>` is more readable and already deployed.
- Keep both formats: Rejected because it adds complexity with no benefit.

**Implementation**: Update the spec scenarios that reference `{{SEC_ID_xxx}}` to use `<<SENSITIVE_xxx>>`.

---

### Decision 4: URL sanitization scope clarification

**Choice**: Clarify in specs that URL sanitization is NOT applied to url-capture output (org-roam requires real URLs for link resolution).

**Rationale**: The code in `sem-security.el` comment states "Do NOT use for org-roam output". org-roam requires real URLs for proper link resolution and backlink functionality. The spec currently incorrectly claims sanitization IS applied. This decision confirms NOT applying sanitization to url-capture output is correct.

**Note**: The code comment at line 85 in `sem-security.el` correctly states the exclusion. However, the spec should be updated to match this behavior.

**Alternatives considered**:
- Apply sanitization to url-capture: Rejected because org-roam link resolution requires real URLs
- Keep both sanitized and unsanitized versions: Rejected as unnecessary complexity

---

### Decision 5: Add comprehensive LLM logging

**Choice**: Add logging to `sem-llm-request` in `sem-llm.el` for prompt length, response length, token counts on success, and full error logging on failure.

**Rationale**: Currently `sem-llm-request` has minimal logging. Adding detailed logging enables:
- Monitoring token usage patterns
- Debugging LLM response issues
- Correlating errors with specific inputs

**Implementation**: Add `sem-core-log` calls at start (prompt length), on success (response length + token count), and on error (full error details with input).

---

### Decision 6: Integration test extensions

**Choice**: Add sensitive block test case to `inbox-tasks.org` and validation logic to `run-integration-tests.sh` for sensitive content restoration and cron/emacsclient verification.

**Rationale**: Current integration tests lack coverage for:
- End-to-end sensitive block round-trip (tokenization → LLM → detokenization)
- Cron job execution via emacsclient

**Alternatives considered**:
- Unit tests for sensitive block handling: Rejected because integration test verifies the full pipeline.
- Mock emacsclient for testing: Rejected because integration test should verify real emacsclient behavior.

**Implementation**: 
- Add `#+begin_sensitive`/`#+end_sensitive` block to `inbox-tasks.org`
- Add shell function in `run-integration-tests.sh` to verify sensitive content restoration in output
- Add shell function to verify emacsclient can execute scheduled commands

---

### Decision 7: Tag format documentation sync

**Choice**: Update tag format in `test-inbox-resource/spec.md` and `README.md` from `@task` / `:@task:` to `:task:` (Org tag syntax uses colons).

**Rationale**: Org tag syntax uses colons (`:task:`), not `@task` or `:@task:`. The specs and README incorrectly document the tag format.

**Alternatives considered**:
- Change code to match spec: Rejected because Org mode standard is colons
- Leave incorrect format: Rejected because it misleads users

**Implementation**: 
- Update `test-inbox-resource/spec.md` scenarios referencing `@task` to use `:task:`
- Update README.md tag format documentation

## Risks / Trade-offs

[Risk] Reasoning exclusion parameter may not work with all reasoning models
→ Mitigation: Test with qwen3.5 first; the parameter is model-specific but gptel will gracefully ignore if unsupported

[Risk] `when-let*` binding semantics differ from `when-let`
→ Mitigation: Checked that bindings are independent in both locations; no value dependencies between bindings

[Risk] Spec updates may drift from code again
→ Mitigation: This change adds no new mechanisms; it's synchronizing existing documentation with existing code

[Risk] Integration test changes could break existing tests
→ Mitigation: Only ADD new test cases; existing test validation unchanged

## Migration Plan

### Phase 1: Code changes (this change)
- Modify `init.el` to add reasoning exclusion
- Modify `sem-rss.el` to replace `when-let` with `when-let*`
- Modify `sem-llm.el` to add comprehensive logging
- Run unit tests to verify no regression

### Phase 2: Spec syncs (this change)
- Update `security-masking/spec.md` token format
- Update `security-masking/spec.md` URL sanitization scope clarification
- Update `test-inbox-resource/spec.md` tag format
- Update `inbox-upload/spec.md` WebDAV path documentation
- Update README.md tag format

### Phase 3: Integration test updates (this change)
- Add sensitive block test case to `inbox-tasks.org`
- Add sensitive content validation to `run-integration-tests.sh`
- Add cron/emacsclient verification to `run-integration-tests.sh`

### Rollback
- Code changes: Revert init.el, sem-rss.el, sem-llm.el changes
- Spec changes: Revert spec files to previous versions
- Integration test changes: Revert test files to previous versions

No data migration required; all changes are additive or documentation fixes.

## Open Questions

1. Should `sem-security.el` comment about org-roam exclusion be updated? (Code behavior is correct, comment is wrong)
2. Does the integration test cron verification need a specific scheduled command to test, or just emacsclient connectivity?

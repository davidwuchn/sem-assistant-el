## Context

This change addresses four defects in the Emacs-based inbox processing system:

1. **Hash mismatch bug**: `sem-core-purge-inbox` uses raw string accumulation for headline body extraction while `sem-router--parse-headlines` uses `org-element`. This causes different SHA-256 hashes, preventing processed headlines from being purged.

2. **Duplicated org-mode cheat sheets**: Multiple modules (`sem-router.el`, `sem-url-capture.el`) hardcode incomplete cheat sheet fragments. The task flow version lacks blockquotes, code blocks, and Orgzly URI schemes.

3. **Implicit output language**: Prompts contain no language instruction, causing non-deterministic language output from LLMs.

4. **No regression test enforcement**: No explicit test gate exists for this change set.

**Stakeholders**: Users with mixed-language inboxes, Orgzly mobile app users, maintainers of the sem-assistant-el system.

## Goals / Non-Goals

**Goals:**
- Fix hash mismatch between purge and parse functions by using consistent `org-element`-based body extraction
- Create centralized `sem-prompts.el` module with comprehensive org-mode cheat sheet
- Add explicit output language instruction to LLM prompts via `OUTPUT_LANGUAGE` env var
- Ensure all tests pass as a gate for this change

**Non-Goals:**
- Changes to `sem-rss.el` (RSS digest language controlled separately)
- Changes to `sem-security.el`, `sem-llm.el`, `sem-git-sync.el`
- Adding validation/normalization of `OUTPUT_LANGUAGE` value
- Runtime caching of environment variable (read at call time)

## Decisions

### D1: Use `org-element`-based extraction for purge hash computation

**Decision**: Replace raw string accumulation in `sem-core-purge-inbox` with a call to `sem-router--extract-headline-body`.

**Rationale**: This ensures consistent body extraction between purge and parse functions. The hash formula remains unchanged; only the body extraction mechanism changes.

**Alternative considered**: Create a new shared extraction function in `sem-core.el`. Rejected because `sem-router--extract-headline-body` already exists and is tested.

**Constraint applied**: `require` is scoped inside the function body to avoid circular dependency at load time.

### D2: Centralize org-mode cheat sheet in new `sem-prompts.el` module

**Decision**: Create a new module `sem-prompts.el` with a single `defconst`: `sem-prompts-org-mode-cheat-sheet`.

**Rationale**: Eliminates duplication across modules. Ensures consistent LLM instructions. Easier maintenance—single source of truth for org-mode syntax.

**Alternative considered**: Keep cheat sheet in one module and require from the other. Rejected because both modules need it, and a new module is cleaner.

**Constraint applied**: No runtime dependencies (no `require` of other sem-* modules). Must `(provide 'sem-prompts)`.

### D3: Extend cheat sheet with missing syntax elements

**Decision**: Include blockquotes, code blocks, all list types, example/verse blocks, tables, and Orgzly URI schemes in the cheat sheet.

**Rationale**: Current cheat sheets are incomplete. URL capture needs blockquotes and code blocks. Orgzly users need URI schemes (`mailto:`, `tel:`, `geo:`).

**Alternative considered**: Keep minimal cheat sheet and add as needed. Rejected because the proposal explicitly requires comprehensive coverage.

### D4: Read `OUTPUT_LANGUAGE` at call time, not load time

**Decision**: Both `sem-router--route-to-task-llm` and `sem-url-capture-process` read `(or (getenv "OUTPUT_LANGUAGE") "English")` at call time.

**Rationale**: Allows changing the language without restarting the Emacs daemon. Simple implementation with no caching complexity.

**Alternative considered**: Read at load time and cache in a variable. Rejected—proposal explicitly requires call-time reading.

**Constraint applied**: Value is used verbatim. No validation. Default is "English" if unset.

### D5: Inject language instruction as final line of system prompt

**Decision**: Append the language instruction after the cheat sheet as the final line of the system prompt.

**Rationale**: Ensures LLM sees language instruction last, increasing likelihood of compliance.

**Format**: `\n\nOUTPUT LANGUAGE: Write your entire response in <value>. Do not use any other language.`

### D6: Test enforcement via existing test runner

**Decision**: Use existing test command `emacs --batch --load app/elisp/tests/sem-test-runner.el` as the regression gate.

**Rationale**: Leverages existing infrastructure. Tests for changed behavior must be updated. No new test framework needed.

**Scope**: Zero failures required. Tests for behavior being changed must be updated. No other regressions permitted.

## Risks / Trade-offs

- **[Risk] Circular dependency**: `sem-core.el` requiring `sem-router.el` could cause issues.
  - **Mitigation**: Scope `(require 'sem-router)` inside `sem-core-purge-inbox` function body, not at top level.

- **[Risk] Cheat sheet bloat**: Comprehensive cheat sheet may increase prompt size and affect LLM response quality.
  - **Mitigation**: Keep cheat sheet as concise as possible while covering required syntax. The proposal constrains it to be self-contained with no format specifiers.

- **[Risk] Garbage in = garbage out**: Invalid `OUTPUT_LANGUAGE` values will be passed verbatim to LLM.
  - **Mitigation**: By design—proposal explicitly states no validation. Users must provide valid language names.

- **[Risk] Test updates may miss edge cases**: Updating existing tests could miss regressions.
  - **Mitigation**: All tests must pass. New tests for `sem-prompts.el` verify constant contains required entries.

- **[Risk] Load order dependency**: `init.el` must load `sem-prompts` before `sem-router` and `sem-url-capture`.
  - **Mitigation**: Explicitly documented in proposal Impact section. Requires update to `sem-init--load-modules`.
## Why

Four independent defects/gaps in the router and shared-prompt layer:

1. **Hash mismatch in purge**: `sem-core-purge-inbox` extracts headline body via raw string accumulation; `sem-router--parse-headlines` uses `org-element`. Different whitespace handling produces divergent SHA-256 hashes — processed headlines are never purged from the inbox.
2. **Duplicated, incomplete org-mode cheat sheets**: Each LLM-calling module hardcodes its own prompt fragment. The task flow's version is a strict subset of the URL capture version (missing blockquotes, code blocks, link syntax, lists). Both omit Orgzly-specific URI link schemes.
3. **Output language is implicit**: Task and URL capture prompts contain no language instruction. LLM mirrors input language non-deterministically across mixed-language inboxes.
4. **Test suite not enforced at change boundary**: No explicit regression gate exists for this change set.

## What Changes

- `sem-core-purge-inbox` body extraction is replaced with `org-element`-based extraction, identical to `sem-router--parse-headlines`.
- A new module `sem-prompts.el` is introduced. It exports a single `defconst`: `sem-prompts-org-mode-cheat-sheet`. Both `sem-router.el` and `sem-url-capture.el` replace their inline cheat-sheet strings with this constant.
- `sem-prompts-org-mode-cheat-sheet` is extended with: blockquotes, code blocks, all list types, `#+begin_example`, `#+begin_verse`, table syntax, Orgzly-supported URI schemes (`mailto:`, `tel:`, `geo:` with query params), and additional bad-example callouts.
- A new env var `OUTPUT_LANGUAGE` is read by `sem-router.el` and `sem-url-capture.el` at call time. The value is injected as a language instruction into system prompts for both the task pipeline and the URL capture pipeline. If unset, the string `"English"` is used as the default — no startup error, no log warning.
- `docker-compose.yml` is updated to declare `OUTPUT_LANGUAGE=English` in the `sem-emacs` service environment.
- The test command `emacs --batch --load app/elisp/tests/sem-test-runner.el` must pass with zero failures before this change is complete. Tests that test behavior being changed SHALL be updated. No other test regressions are permitted.

## Capabilities

### New Capabilities

- `sem-prompts-org-mode-cheat-sheet`: A `defconst` string in `sem-prompts.el` containing the canonical org-mode syntax cheat sheet for LLM system prompts. Constraints:
  - MUST cover: headings (`*`), bold (`*...*`), italic (`/.../`), underline (`_..._`), strikethrough (`+...+`), inline code (`=...=`, `~...~`), code blocks (`#+begin_src`/`#+end_src`), blockquotes (`#+begin_quote`/`#+end_quote`), example blocks (`#+begin_example`/`#+end_example`), verse blocks (`#+begin_verse`/`#+end_verse`), unordered lists (`-`, `+`), ordered lists (`1.`, `1)`), description lists (`- term :: description`), tables (`| col | col |` with `|-` separator), internal links (`[[*heading][desc]]`), external links (`[[url][desc]]`), id links (`[[id:UUID][desc]]`), file links (`[[file:path][desc]]`).
  - MUST cover Orgzly-supported URI schemes as valid link targets: `mailto:user@example.com`, `tel:1-800-555-0199`, `geo:40.7128,-74.0060`, `geo:0,0?q=new+york+city`, `geo:40.7128,-74.0060?z=11`.
  - MUST include explicit BAD/GOOD callouts for each common LLM mistake: `# heading` → `* heading`, `` `code` `` → `=code=`, `**bold**` → `*bold*`, `*italic*` → `/italic/`, `> quote` → `#+begin_quote`, ` ```lang``` ` → `#+begin_src lang`, `[desc](url)` → `[[url][desc]]`.
  - MUST include the rule: never wrap the entire output in a markdown code fence.
  - The string MUST be self-contained (no format specifiers). It is concatenated into system prompts, not passed to `format`.
  - `sem-prompts.el` MUST `(provide 'sem-prompts)` and have no runtime dependencies (no `require` of other sem-* modules).

- `output-language-instruction`: Both `sem-router--route-to-task-llm` and `sem-url-capture-process` read `(or (getenv "OUTPUT_LANGUAGE") "English")` at call time (not at load time, not cached in a global). The value is appended to their respective system prompts as: `\n\nOUTPUT LANGUAGE: Write your entire response in <value>. Do not use any other language.`. Constraints:
  - Read at call time so the env var can be changed without restarting the daemon.
  - The instruction is the final line of the system prompt, appended after the cheat sheet.
  - Value is used verbatim — no validation, no normalization. Garbage in = garbage instruction to LLM.
  - Scope: `sem-router.el` (task pipeline) and `sem-url-capture.el` (link pipeline) only. `sem-rss.el` is NOT changed — RSS digest language is controlled separately via prompt files.

### Modified Capabilities

- `inbox-purge`: `sem-core-purge-inbox` body extraction is changed. It MUST call `sem-router--extract-headline-body` (via `require 'sem-router` inside the function body) to extract body text from each headline element during purge hash computation. The hash formula remains `(secure-hash 'sha256 (concat title "|" space-joined-tags "|" body-or-empty))` — unchanged. Only the body extraction mechanism changes. Constraint: `sem-core.el` MUST NOT have a top-level `(require 'sem-router)` — the require is scoped inside `sem-core-purge-inbox` only, to avoid circular dependency at load time. `sem-router--extract-headline-body` MUST be callable with only the `headline-element` argument (no change to its signature).

- `task-llm-pipeline`: System prompt in `sem-router--route-to-task-llm` is replaced with concatenation of `sem-prompts-org-mode-cheat-sheet` + task-specific instructions + output language instruction. The task-specific instructions (required output format, UUID rule, FILETAGS rule) are preserved verbatim. Nothing else in the task pipeline changes.

- `url-capture`: System prompt in `sem-url-capture--build-system-prompt` is replaced with concatenation of `sem-prompts-org-mode-cheat-sheet` + url-capture-specific instructions + output language instruction. The url-capture-specific instructions (node structure, umbrella links, ROAM_REFS, etc.) are preserved verbatim. Nothing else in the url-capture pipeline changes.

## Impact

- `sem-prompts.el` is a new file. `sem-router.el` and `sem-url-capture.el` gain `(require 'sem-prompts)`.
- `init.el` (`sem-init--load-modules`) MUST load `sem-prompts` before `sem-router` and `sem-url-capture`.
- `sem-core.el` gains a scoped `(require 'sem-router)` inside `sem-core-purge-inbox` only.
- `docker-compose.yml`: `sem-emacs` service gains `OUTPUT_LANGUAGE=English` under `environment`.
- Tests: `sem-core-test.el` purge hash tests MUST be updated to use body extracted via `sem-router--extract-headline-body` rather than the old string accumulation. `sem-router-test.el` and `sem-url-capture-test.el` system prompt tests MUST be updated to expect the new shared cheat sheet. New tests for `sem-prompts.el` MUST verify the constant is non-empty and contains required syntax entries. All other tests MUST pass without modification.
- No changes to `sem-rss.el`, `sem-security.el`, `sem-llm.el`, `sem-git-sync.el`, or any spec files outside this change.

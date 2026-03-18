## 1. Create sem-prompts.el Module

- [x] 1.1 Create `app/elisp/sem-prompts.el` with `(provide 'sem-prompts)`
- [x] 1.2 Define `sem-prompts-org-mode-cheat-sheet` defconst with all required syntax (headings, bold, italic, underline, strikethrough, inline code, code blocks, blockquotes, example blocks, verse blocks, lists, tables, links)
- [x] 1.3 Add Orgzly URI schemes to cheat sheet (mailto:, tel:, geo:)
- [x] 1.4 Add BAD/GOOD callouts for common LLM mistakes
- [x] 1.5 Add rule against wrapping output in markdown code fences
- [x] 1.6 Verify cheat sheet has no format specifiers (self-contained string)

## 2. Update init.el Load Order

- [x] 2.1 Modify `sem-init--load-modules` in `init.el` to load `sem-prompts` before `sem-router` and `sem-url-capture`

## 3. Update sem-router.el

- [x] 3.1 Add `(require 'sem-prompts)` to sem-router.el
- [x] 3.2 Update `sem-router--route-to-task-llm` to concatenate cheat sheet + task instructions + language instruction
- [x] 3.3 Add call-time reading of `OUTPUT_LANGUAGE` env var with default "English"
- [x] 3.4 Append language instruction as final line of system prompt

## 4. Update sem-url-capture.el

- [x] 4.1 Add `(require 'sem-prompts)` to sem-url-capture.el
- [x] 4.2 Update `sem-url-capture--build-system-prompt` to concatenate cheat sheet + url-capture instructions + language instruction
- [x] 4.3 Add call-time reading of `OUTPUT_LANGUAGE` env var with default "English"
- [x] 4.4 Append language instruction as final line of system prompt

## 5. Fix Hash Mismatch in sem-core.el

- [x] 5.1 Add scoped `(require 'sem-router)` inside `sem-core-purge-inbox` function body
- [x] 5.2 Replace raw string body extraction with call to `sem-router--extract-headline-body`
- [x] 5.3 Verify hash formula remains unchanged: `(secure-hash 'sha256 (concat title "|" space-joined-tags "|" body-or-empty))`

## 6. Update docker-compose.yml

- [x] 6.1 Add `OUTPUT_LANGUAGE=English` to `sem-emacs` service environment

## 7. Update and Run Tests

- [x] 7.1 Update `sem-core-test.el` purge hash tests to use `sem-router--extract-headline-body`
- [x] 7.2 Update `sem-router-test.el` system prompt tests to expect new shared cheat sheet
- [x] 7.3 Update `sem-url-capture-test.el` system prompt tests to expect new shared cheat sheet
- [x] 7.4 Add new tests for `sem-prompts.el` to verify constant is non-empty and contains required syntax entries
- [x] 7.5 Run test command: `emacs --batch --load app/elisp/tests/sem-test-runner.el`
- [x] 7.6 Verify zero test failures

## 8. Verify No Regressions

- [x] 8.1 Verify `sem-rss.el` is unchanged
- [x] 8.2 Verify `sem-security.el` is unchanged
- [x] 8.3 Verify `sem-llm.el` is unchanged
- [x] 8.4 Verify `sem-git-sync.el` is unchanged
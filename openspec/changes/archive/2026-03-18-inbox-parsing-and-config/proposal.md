## Why

Three independent correctness and usability defects:

1. `sem-router--parse-headlines` uses ad-hoc regex to parse Org files. Emacs ships the reference Org parser (`org-element`). The regex parser silently discards headline body text, making task context invisible to the LLM. It is also fragile against nested headlines, drawers, and planning lines.

2. RSS prompts (general and arXiv) are hardcoded Elisp strings with Russian language and personal category preferences baked in. They cannot be changed without rebuilding the container. Users need to mount custom prompt files.

3. `tasks.org` and `inbox-mobile.org` are subject to a silent read-modify-write race: Orgzly (WebDAV) can write to these files at the same time the server appends a task or purges the inbox. Data loss occurs with no error logged. The README must warn users of the safe sync windows.

## What Changes

- `sem-router--parse-headlines` is replaced with an `org-element`-based parser that captures `:title`, `:tags`, `:body`, `:point`, `:hash` per headline.
- `sem-router--route-to-task-llm` receives and uses the body. Body is masked with `sem-security-sanitize-for-llm` before sending to LLM. LLM response is restored with `sem-security-restore-from-llm` before validation and file write.
- Cursor hash changes to `sha256(title + "|" + tags + "|" + body)`.
- `sem-rss--build-general-prompt` and `sem-rss--build-arxiv-prompt` read prompt templates from `/data/prompts/general-prompt.txt` and `/data/prompts/arxiv-prompt.txt`. Both are read once at daemon startup into `defvar` globals. Missing file at startup is a hard error (daemon aborts).
- `docker-compose.yml` mounts `./data/prompts/` (already under `./data:/data`; no new mount needed).
- `README.md` gains a prominently placed warning about the race condition and safe Orgzly sync windows.

## Capabilities

### New Capabilities

- `task-body-capture`: Headlines parsed via `org-element-parse-buffer` + `org-element-map`. Each headline plist gains a `:body` key containing the raw text of all content between the headline line and the next sibling/parent headline (stripped of leading/trailing whitespace). If the headline has no body, `:body` is `nil`. Nested sub-headlines are NOT included in the body — only the direct content nodes (paragraph, plain-list, planning, property-drawer are extracted; sub-headlines are excluded).

- `task-body-to-llm`: For `@task` headlines, `:body` (if non-nil) is appended to the LLM user prompt as a `BODY:` section after `HEADLINE:`. Body text is passed through `sem-security-sanitize-for-llm` first; the returned `security-blocks` alist is stored in the LLM context plist alongside `:injected-id` and `:hash`. After LLM response arrives, `sem-security-restore-from-llm` is called on the response using the stored `security-blocks` before validation and file write. If `:body` is `nil`, no `BODY:` section is added to the prompt and no masking is performed.

- `rss-prompt-from-file`: Two `defvar` globals (`sem-rss-general-prompt-template` and `sem-rss-arxiv-prompt-template`) are populated at module load time by reading `/data/prompts/general-prompt.txt` and `/data/prompts/arxiv-prompt.txt`. If either file does not exist or is empty, `sem-rss` load signals a hard error. `sem-rss--build-general-prompt` and `sem-rss--build-arxiv-prompt` call `format` on the loaded template string with positional `%s` arguments in the same order as the current hardcoded strings (days, category-list, days, entries-text for general; category-list, days, entries-text for arXiv). The existing function signatures are unchanged.

### Modified Capabilities

- `sem-router--parse-headlines`: Regex loop replaced with `org-element-parse-buffer` + `org-element-map` over `headline` type elements. Returns the same plist shape as before plus `:body`. Hash computation changes to include body: `(secure-hash 'sha256 (concat title "|" (or tags-str "") "|" (or body "")))`. Tags are extracted via `org-element-property :tags` (returns a list of strings without colons). Title is extracted via `org-element-property :raw-value`. Body is extracted as the concatenated text of all non-headline child elements of the headline, trimmed.

- `sem-router--route-to-task-llm`: Reads `:body` from the headline plist. If non-nil: calls `sem-security-sanitize-for-llm` on body text, stores `security-blocks` in context plist. Appends `\nBODY:\n<tokenized-body>` to the user prompt after the `HEADLINE:` line. After LLM response: calls `sem-security-restore-from-llm response security-blocks` before passing to `sem-router--validate-task-response`.

- `sem-rss--build-general-prompt` / `sem-rss--build-arxiv-prompt`: Replace inline `format` string literals with `format sem-rss-general-prompt-template ...` / `format sem-rss-arxiv-prompt-template ...`. Argument order and types are unchanged.

- `README.md`: Add a **WARNING** section immediately after the "Scheduled Tasks" table titled "Orgzly Sync Timing". Content: Orgzly must not sync (push or pull) during the windows `XX:28–XX:32` and `XX:58–XX:02` (every hour, on the :00 and :30 cron triggers). Also avoid syncing during `04:00–04:05` (purge window). Reason: the server performs non-atomic read-modify-write on `tasks.org` and non-atomic file replacement on `inbox-mobile.org` during these windows. Concurrent writes will cause silent data loss.

## Impact

### Test command

All tests are run with:
```
emacs --batch --load app/elisp/tests/sem-test-runner.el
```
Zero test failures are required. Pre-existing passing tests must not regress.

### Test files: MUST NOT be modified (must pass unchanged)

These test files cover code paths not touched by this change. The junior must not edit them. They must pass 100% after the change:

- `sem-core-test.el` — logging, cursor, purge; none of this changes
- `sem-security-test.el` — tokenize/detokenize, URL sanitization; security module is unchanged
- `sem-llm-test.el` — gptel wrapper; unchanged
- `sem-async-test.el` — async return behavior; unchanged (note: this file mocks `sem-security-sanitize-urls` which is vestigial; do not remove the mock)
- `sem-retry-test.el` — retry/DLQ logic; unchanged
- `sem-git-sync-test.el` — SSH agent lifecycle; unchanged
- `sem-url-capture-test.el` — URL capture pipeline; unchanged
- `sem-url-sanitize-test.el` — org-roam URL defanging policy; unchanged
- `sem-init-test.el` — module load order; unchanged

### Test files: MUST be modified

**`sem-router-test.el`** — directly tests `sem-router--parse-headlines` and `sem-router--route-to-task-llm`:
- Every test that constructs a headline plist literal must add `:body nil` (or an explicit body string where the test exercises body behavior).
- Every test that asserts a specific hash value must recompute it: new formula is `sha256(title + "|" + tags + "|" + body)` where body is `""` when nil.
- The `sem-router--parse-headlines` tests must be rewritten to insert Org text into a temp buffer and call the new `org-element`-based parser. Regex-specific assertions are removed.
- New tests required: (a) headline with body → `:body` is non-nil and correct; (b) headline without body → `:body` is nil; (c) nested sub-headline is NOT included in body; (d) `@task` with nil body → LLM prompt contains no `BODY:` section; (e) `@task` with body → LLM prompt contains `BODY:` section; (f) `@task` with `#+begin_sensitive` in body → body is masked before LLM send, response is restored before validation.

**`sem-rss-test.el`** — directly tests prompt builders and module load:
- Tests that assert exact prompt string content must be updated to use the template variables (`sem-rss-general-prompt-template`, `sem-rss-arxiv-prompt-template`) rather than hardcoded string literals.
- New tests required: (a) `sem-rss` load with prompt files present → globals are non-nil and non-empty; (b) `sem-rss` load with a missing prompt file → signals an error.
- Tests that assert `sem-llm-request` is used (not `gptel-request`) are unchanged.

### Non-test files: MUST be modified

- `sem-router.el`: `sem-router--parse-headlines`, `sem-router--route-to-task-llm`
- `sem-rss.el`: `sem-rss--build-general-prompt`, `sem-rss--build-arxiv-prompt`, plus new `defvar` globals and file-read logic at module load
- `README.md`: race condition warning, deployment instructions for prompt files

### Non-test files: MUST NOT be modified

- `sem-core.el`, `sem-security.el`, `sem-llm.el`, `sem-url-capture.el`, `sem-git-sync.el`, `init.el`, `docker-compose.yml`, `Dockerfile.emacs`, `crontab`, `sem-mock.el`, `sem-test-runner.el`

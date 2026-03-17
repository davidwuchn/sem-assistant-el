## Why

Five functional defects prevent the system from working as described in the README:
1. A `cl-return-from` without a `cl-block` in `sem-router--parse-headlines` crashes every 30-minute cron run, making URL capture dead in production.
2. `@task` inbox headlines are silently discarded (stub marks them processed with no LLM call).
3. `sem-security-sanitize-for-llm` and `sem-security-sanitize-urls` are implemented but never called — README guarantees are not upheld.
4. `sem-core-purge-inbox` discards body content of unprocessed headlines, causing silent data loss at 4AM.
5. `sem-rss--generate-file` calls `gptel-request` directly, bypassing the retry/DLQ policy enforced by `sem-llm-request`.

## What Changes

- `sem-router.el`: fix parse crash; implement task LLM pipeline with auto-tagging
- `sem-core.el`: fix purge to preserve full headline subtrees
- `sem-url-capture.el`: wire security masking before LLM call; wire URL sanitization on LLM response before file write
- `sem-rss.el`: route `sem-rss--generate-file` through `sem-llm-request`

## Capabilities

### New Capabilities

- `task-llm-pipeline`: `@task` headlines are sent to the LLM, which returns a single valid org TODO entry. The entry must include: a cleaned title, optional DEADLINE/SCHEDULED/PRIORITY, a one-line description, a `:PROPERTIES:` drawer with `:ID:` (new `org-id`), and `:FILETAGS:` set to exactly one tag from the allowed list `("work" "family" "routine" "opensource")`. If the LLM returns an absent or invalid tag, the Elisp layer substitutes `:routine:` before writing. The validated entry is appended to `/data/tasks.org` (created if absent). Same retry/DLQ policy as `sem-url-capture-process`: API errors leave the hash unrecorded (retry next cron); malformed LLM output goes to `errors.org` and marks the hash as processed (no infinite retry).

### Modified Capabilities

- `inbox-processing`: `sem-router--parse-headlines` must be wrapped in `(cl-block sem-router--parse-headlines ...)` so that `cl-return-from` is valid. No behavior change beyond eliminating the crash. Constraint: the fix is limited to adding the `cl-block` wrapper; no other logic in the function changes.

- `inbox-purge`: `sem-core-purge-inbox` must preserve the full subtree of each unprocessed headline (title line + all body lines until the next top-level `* ` headline or EOF). The temp-file write must use region-based or org-element-based copy — writing only the title string is forbidden. Atomic rename behavior is unchanged.

- `security-masking`: `sem-url-capture-process` must call `sem-security-sanitize-for-llm` on the sanitized article text before passing it to `sem-llm-request`. The returned `blocks` alist must be stored in the context plist under `:security-blocks`. After `sem-llm-request` returns, `sem-security-restore-from-llm` is NOT called (LLM output is a new document, not a transformed version of the input). `sem-security-sanitize-urls` must be applied to the raw LLM response string before it is passed to `sem-url-capture--validate-and-save`. The `sem-url-capture--validate-and-save` function signature and behavior are unchanged.

- `rss-digest`: `sem-rss--generate-file` must replace its direct `gptel-request` call with `sem-llm-request`. RSS digest has no per-entry cursor deduplication; pass `nil` as the `hash` argument. On malformed LLM output, log to `errors.org` and do not write the output file. On API error, log RETRY status and do not write the output file (the daily file-existence check means the digest will not be retried today; this is acceptable).

## Impact

- `sem-router-test.el`: add a test that calls `sem-router--parse-headlines` on a temp file containing at least one headline. This proves the `cl-block` fix at runtime, not just at parse time.
- `sem-router-test.el`: add tests for `sem-router--route-to-task-llm` covering: success path (valid org TODO with valid tag appended to tasks.org), DLQ path (malformed LLM output → errors.org, hash marked), retry path (API error → hash NOT marked).
- `sem-core-test.el`: add a test that creates an inbox with one processed and one unprocessed headline (each with body lines), runs `sem-core-purge-inbox`, and asserts the unprocessed headline's body is present in the output file.
- `sem-url-capture-test.el`: add a test asserting that the text passed to `sem-llm-request` has sensitive blocks tokenized; add a test asserting that the LLM response passed to `validate-and-save` has URLs defanged (`hxxp://`).
- `sem-rss-test.el`: add a test asserting `sem-rss--generate-file` invokes `sem-llm-request` (not `gptel-request`).
- Allowed task tags (`sem-router-task-tags`) are a `defconst` in `sem-router.el`. Changing them requires a code change and container rebuild.
- `sem-security-restore-from-llm` is explicitly NOT called in the url-capture pipeline. This is intentional: LLM output is a new org document, not a transformed version of the input.
- `sem-rss--generate-file` receives `nil` as hash. `sem-llm-request` and its helpers must handle `nil` hash without crashing (e.g., `sem-core--mark-processed nil` must be a no-op).

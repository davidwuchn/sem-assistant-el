## Context

The current implementation has three independent defects affecting correctness and usability:

1. **Fragile headline parsing**: `sem-router--parse-headlines` uses ad-hoc regex to parse Org files. This approach silently discards headline body text (making task context invisible to the LLM) and is fragile against nested headlines, drawers, and planning lines. Emacs ships with the reference Org parser (`org-element`) which should be used instead.

2. **Hardcoded RSS prompts**: RSS prompts (general and arXiv) are hardcoded Elisp strings with Russian language and personal category preferences baked in. Users cannot customize prompts without rebuilding the container.

3. **Silent data race**: `tasks.org` and `inbox-mobile.org` are subject to a read-modify-write race condition. Orgzly (WebDAV) can write to these files at the same time the server appends a task or purges the inbox, causing silent data loss.

## Goals / Non-Goals

**Goals:**
- Replace regex-based headline parser with `org-element`-based parser that captures `:title`, `:tags`, `:body`, `:point`, `:hash` per headline
- Enable body text capture for `@task` headlines to provide LLM with task context
- Implement security masking/unmasking for body text sent to LLM
- Move RSS prompt templates to external files (`/data/prompts/general-prompt.txt`, `/data/prompts/arxiv-prompt.txt`)
- Add prominent README warning about Orgzly sync timing to prevent data loss
- Update hash computation to include body content for better change detection
- Ensure all existing tests pass with necessary updates to hash assertions and headline plist structures

**Non-Goals:**
- Changing the security tokenization mechanism (remains unchanged)
- Modifying the async, retry, DLQ, git-sync, or URL capture pipelines
- Adding atomic file operations or file locking (out of scope; documentation-only mitigation)
- Supporting dynamic prompt reloading without daemon restart
- Changing the cron schedule or purge logic

## Decisions

### 1. Use `org-element-parse-buffer` + `org-element-map` for headline parsing

**Rationale**: `org-element` is the reference parser shipped with Emacs. It correctly handles nested structures, drawers, planning lines, and edge cases that regex cannot reliably parse.

**Implementation approach**:
- Use `org-element-parse-buffer` to get the full AST
- Use `org-element-map` with type `'headline` to iterate over all headlines
- Extract title via `org-element-property :raw-value`
- Extract tags via `org-element-property :tags` (returns list of strings without colons)
- Extract body by collecting text of all non-headline child elements (paragraph, plain-list, planning, property-drawer), excluding nested sub-headlines

**Alternatives considered**:
- Keep regex and enhance it: Rejected because regex cannot reliably handle nested structures and Org syntax edge cases.
- Use `org-map-entries`: Rejected because it doesn't provide easy access to body content between headlines.

### 2. Body content extraction excludes nested sub-headlines

**Rationale**: Including nested sub-headlines would create recursive complexity and potentially send too much context to the LLM. The body should only include direct content of the headline being processed.

**Implementation approach**:
- When extracting body, traverse child elements of the headline
- Include text from `paragraph`, `plain-list`, `planning`, `property-drawer` elements
- Stop traversal when encountering a `headline` element (exclude nested headlines)
- Trim leading/trailing whitespace from collected body text
- Store `nil` if no body content exists

### 3. Security masking applied only when body is non-nil

**Rationale**: The security module (`sem-security-sanitize-for-llm` / `sem-security-restore-from-llm`) is designed to mask sensitive content. It should only be invoked when there is actual body content to mask.

**Implementation approach**:
- If `:body` is non-nil, call `sem-security-sanitize-for-llm` before sending to LLM
- Store returned `security-blocks` alist in the LLM context plist alongside `:injected-id` and `:hash`
- After LLM response, call `sem-security-restore-from-llm` using stored `security-blocks` before validation and file write
- If `:body` is nil, skip masking entirely and omit `BODY:` section from prompt

### 4. Hash computation includes body content

**Rationale**: Body content affects LLM routing decisions and task output. Changes to body should be detected as changes to the headline.

**Implementation approach**:
- New formula: `(secure-hash 'sha256 (concat title "|" (or tags-str "") "|" (or body "")))`
- Empty string used for nil body to ensure consistent hashing

### 5. Prompt templates loaded at module load time with hard error on missing files

**Rationale**: Prompt files are configuration, not code. Loading at startup ensures immediate feedback if configuration is missing. Hard error prevents the daemon from running with undefined behavior.

**Implementation approach**:
- Two new `defvar` globals: `sem-rss-general-prompt-template` and `sem-rss-arxiv-prompt-template`
- Read files at `sem-rss` module load time using `with-temp-buffer` and `insert-file-contents`
- Signal error with descriptive message if file missing or empty
- Use `format` with loaded template string, keeping same positional `%s` arguments as current hardcoded strings

**Alternatives considered**:
- Lazy loading on first RSS run: Rejected because delayed failure makes debugging harder.
- Default fallback prompts: Rejected because silent fallback hides configuration errors.

### 6. Documentation-only mitigation for race condition

**Rationale**: Implementing atomic file operations or file locking would require significant changes to the architecture and testing. Given the specific use case (personal server with known sync windows), documentation is an acceptable short-term mitigation.

**Implementation approach**:
- Add **WARNING** section to README immediately after "Scheduled Tasks" table
- Title: "Orgzly Sync Timing"
- Specify unsafe windows: `XX:28–XX:32` and `XX:58–XX:02` (every hour, on :00 and :30 cron triggers), plus `04:00–04:05` (purge window)
- Explain reason: non-atomic read-modify-write operations

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| `org-element` parser may have different performance characteristics than regex | Test with large Org files; `org-element` is generally efficient and widely used |
| Hash changes will invalidate all existing cursors on first run after deployment | Acceptable - headlines will be reprocessed once, no data loss |
| Body extraction may include unexpected content (e.g., drawers) | Explicitly test drawer handling; `org-element` provides properties to identify drawer content |
| Prompt file errors prevent daemon startup | Clear error message guides user to create required files; this is intentional fail-fast behavior |
| Users may not read README warning about race condition | Place warning prominently; consider future implementation of file locking |
| Security masking adds overhead to LLM requests | Only applied when body exists; overhead is minimal compared to LLM API latency |

## Migration Plan

1. **Pre-deployment**:
   - Create `/data/prompts/general-prompt.txt` and `/data/prompts/arxiv-prompt.txt` with desired prompt content
   - Verify files are readable and non-empty

2. **Deployment**:
   - Deploy new code version
   - Daemon will load prompt files at startup (hard error if missing)
   - First run will recompute all headline hashes (one-time reprocessing)

3. **Rollback**:
   - Revert to previous code version
   - Hashes will mismatch again (one-time reprocessing on rollback)

4. **User communication**:
   - Notify users of new prompt file requirement
   - Point to README for Orgzly sync timing guidance

## Open Questions (Resolved)

1. **Prompt file format**: Should we support multi-line templates with specific placeholder syntax (e.g., `{{days}}` instead of `%s`)? Current decision uses `%s` for minimal change. --> keep %s for minimal change of the existing flow;

2. **Body size limits**: Should we truncate very large bodies before sending to LLM? Current decision sends full body; may need limit if LLM context windows are exceeded. --> keep the same limit (40_000) as for other flows

3. **Race condition long-term fix**: Should we implement file locking or atomic writes in a future change? Current decision documents the risk; future work could add `flock` or write-to-temp-then-rename patterns. --> For now document the risk only; implementation is very tricky and not critical (with loud language in README, it is ok for now to skip 4 minutes from hour on the user side)

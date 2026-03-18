## 1. Setup and Preparation

- [x] 1.1 Create `/data/prompts/` directory structure
- [x] 1.2 Create `/data/prompts/general-prompt.txt` with default template content
- [x] 1.3 Create `/data/prompts/arxiv-prompt.txt` with default template content
- [x] 1.4 Verify prompt files are readable and non-empty

## 2. Implement org-element Headline Parser

- [x] 2.1 Replace regex loop in `sem-router--parse-headlines` with `org-element-parse-buffer`
- [x] 2.2 Use `org-element-map` with type `'headline` to iterate over headlines
- [x] 2.3 Extract title via `org-element-property :raw-value`
- [x] 2.4 Extract tags via `org-element-property :tags` (returns list without colons)
- [x] 2.5 Implement body extraction: collect text of non-headline child elements
- [x] 2.6 Exclude nested sub-headlines from body extraction
- [x] 2.7 Trim leading/trailing whitespace from body, set to `nil` if empty
- [x] 2.8 Update hash computation to include body: `sha256(title + "|" + tags + "|" + body)`
- [x] 2.9 Return plist with `:title`, `:tags`, `:body`, `:point`, `:hash`

## 3. Implement Body-to-LLM Integration

- [x] 3.1 Modify `sem-router--route-to-task-llm` to read `:body` from headline plist
- [x] 3.2 Add conditional: if `:body` is non-nil, call `sem-security-sanitize-for-llm`
- [x] 3.3 Store returned `security-blocks` alist in context plist
- [x] 3.4 Append `\nBODY:\n<sanitized-body>` to user prompt after `HEADLINE:` section
- [x] 3.5 If `:body` is nil, skip BODY section and security handling
- [x] 3.6 After LLM response, call `sem-security-restore-from-llm` with stored `security-blocks`
- [x] 3.7 Pass restored response to `sem-router--validate-task-response`

## 4. Implement RSS Prompt File Loading

- [x] 4.1 Add `defvar sem-rss-general-prompt-template` to `sem-rss.el`
- [x] 4.2 Add `defvar sem-rss-arxiv-prompt-template` to `sem-rss.el`
- [x] 4.3 Implement file reading at module load time using `with-temp-buffer` and `insert-file-contents`
- [x] 4.4 Signal hard error if `/data/prompts/general-prompt.txt` missing or empty
- [x] 4.5 Signal hard error if `/data/prompts/arxiv-prompt.txt` missing or empty
- [x] 4.6 Store file contents in the `defvar` globals

## 5. Update RSS Prompt Builders

- [x] 5.1 Modify `sem-rss--build-general-prompt` to use `sem-rss-general-prompt-template`
- [x] 5.2 Modify `sem-rss--build-arxiv-prompt` to use `sem-rss-arxiv-prompt-template`
- [x] 5.3 Keep argument order unchanged: general (days, category-list, days, entries-text)
- [x] 5.4 Keep argument order unchanged: arxiv (category-list, days, entries-text)
- [x] 5.5 Remove hardcoded string literals from both functions

## 6. Update README Documentation

- [x] 6.1 Add **WARNING** section after "Scheduled Tasks" table
- [x] 6.2 Title: "Orgzly Sync Timing"
- [x] 6.3 Document unsafe windows: `XX:28–XX:32` and `XX:58–XX:02`
- [x] 6.4 Document purge window: `04:00–04:05`
- [x] 6.5 Explain reason: non-atomic read-modify-write operations cause silent data loss
- [x] 6.6 Add deployment instructions for prompt files

## 7. Update Tests for Router Module

- [x] 7.1 Update `sem-router-test.el`: add `:body nil` to all headline plist literals
- [x] 7.2 Update hash assertions to use new formula with body
- [x] 7.3 Rewrite `sem-router--parse-headlines` tests to use temp buffer with Org text
- [x] 7.4 Remove regex-specific assertions
- [x] 7.5 Add test: headline with body → `:body` is non-nil and correct
- [x] 7.6 Add test: headline without body → `:body` is nil
- [x] 7.7 Add test: nested sub-headline NOT included in body
- [x] 7.8 Add test: `@task` with nil body → LLM prompt contains no `BODY:` section
- [x] 7.9 Add test: `@task` with body → LLM prompt contains `BODY:` section
- [x] 7.10 Add test: `@task` with `#+begin_sensitive` in body → body masked before LLM, restored after

## 8. Update Tests for RSS Module

- [x] 8.1 Update `sem-rss-test.el`: replace hardcoded prompt assertions with template variables
- [x] 8.2 Add test: `sem-rss` load with prompt files present → globals non-nil and non-empty
- [x] 8.3 Add test: `sem-rss` load with missing prompt file → signals error
- [x] 8.4 Add test: `sem-rss` load with empty prompt file → signals error
- [x] 8.5 Verify existing `sem-llm-request` assertions remain unchanged

## 9. Verification and Validation

- [x] 9.1 Run full test suite: `emacs --batch --load app/elisp/tests/sem-test-runner.el`
- [x] 9.2 Verify zero test failures
- [x] 9.3 Verify `sem-core-test.el` passes unchanged
- [x] 9.4 Verify `sem-security-test.el` passes unchanged
- [x] 9.5 Verify `sem-llm-test.el` passes unchanged
- [x] 9.6 Verify `sem-async-test.el` passes unchanged
- [x] 9.7 Verify `sem-retry-test.el` passes unchanged
- [x] 9.8 Verify `sem-git-sync-test.el` passes unchanged
- [x] 9.9 Verify `sem-url-capture-test.el` passes unchanged
- [x] 9.10 Verify `sem-url-sanitize-test.el` passes unchanged
- [x] 9.11 Verify `sem-init-test.el` passes unchanged
- [x] 9.12 Test daemon startup with missing prompt files → hard error
- [x] 9.13 Test daemon startup with valid prompt files → successful load

## 10. Deployment Preparation

- [x] 10.1 Document prompt file format and placeholders in README
- [x] 10.2 Create example prompt files for reference
- [x] 10.3 Verify docker-compose.yml already mounts `./data:/data` (no changes needed)
- [x] 10.4 Review migration plan for hash recomputation on first run

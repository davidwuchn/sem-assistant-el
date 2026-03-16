## 1. Project Structure & Docker Setup

- [x] 1.1 Create directory structure: `/app/elisp/`, `/data/`, `./logs/` mount point
- [x] 1.2 Write Dockerfile for Emacs container with Python/trafilatura dependency
- [x] 1.3 Write Dockerfile for WebDAV container (davserver)
- [x] 1.4 Write docker-compose.yml with two services, shared `/data` volume, and `./logs` mount
- [x] 1.5 Create `.env.example` with `OPENROUTER_KEY`, `OPENROUTER_MODEL`, `RSS_MAX_ENTRIES_PER_FEED`, `RSS_MAX_INPUT_CHARS`
- [x] 1.6 Write crontab file with all scheduled tasks (inbox-processing, purge, elfeed-update, rss-digest)
- [x] 1.7 Add read-only SSH credentials volume declaration to Emacs container in `docker-compose.yml`: `~/.ssh/vps-org-roam:/root/.ssh:ro` (pre-wired for future github-integration; currently unused and may be empty)

## 2. Bootstrap & Package Management

- [x] 2.1 Create `bootstrap-packages.el` with straight.el bootstrapping logic
- [x] 2.2 Create `straight/versions/default.el` lockfile pinning gptel, elfeed, elfeed-org, org-roam, websocket
- [x] 2.3 Update Dockerfile to run `emacs --batch --load bootstrap-packages.el` at build time
- [x] 2.4 Verify Docker build fails if any package installation fails

## 3. Core Initialization (init.el)

- [x] 3.1 Implement env var validation for `OPENROUTER_KEY` and `OPENROUTER_MODEL`
- [x] 3.2 Configure gptel with OpenRouter backend using lambda for API key
- [x] 3.3 Set global paths: `org-roam-directory`, `elfeed-db-directory`, `rmh-elfeed-org-files`
- [x] 3.4 Set security globals: `create-lockfiles nil`, `enable-local-variables nil`, org-babel safety
- [x] 3.5 Implement git pre-wiring: check `/data/org-roam/.git/`, init if absent, write `.gitignore`
- [x] 3.6 Implement Elfeed DB load with corruption recovery (wipe only on error)
- [x] 3.7 Implement org-roam DB rebuild: delete old DB, call `org-roam-db-sync`
- [x] 3.8 Install `*Messages*` redirection hook to `/var/log/sem/messages.log`
- [x] 3.9 Add error wrapping around all startup steps to prevent daemon abort

## 4. Core Module (sem-core.el)

- [x] 4.1 Implement `sem-core-log` function writing to `/data/sem-log.org` with proper heading structure
- [x] 4.2 Implement `sem-core-log-error` function appending to `/data/errors.org`
- [x] 4.3 Implement `sem-core--flush-messages` for `*Messages*` persistence
- [x] 4.4 Implement `sem-core-process-inbox` as cron entry point for inbox processing
- [x] 4.5 Implement `sem-core-purge-inbox` with atomic rename-file pattern
- [x] 4.6 Add error handling wrappers to all core functions

## 5. Security Module (sem-security.el)

- [x] 5.1 Implement sensitive block detection (`#+begin_sensitive` / `#+end_sensitive`)
- [x] 5.2 Implement token replacement function for LLM input sanitization
- [x] 5.3 Implement token restoration function for LLM output
- [x] 5.4 Implement URL sanitization (`http` → `hxxp`) for tasks.org and morning-read output
- [x] 5.5 Verify URL sanitization is NOT applied to org-roam output

## 6. LLM Module (sem-llm.el)

- [x] 6.1 Implement `sem-llm-request` wrapper around `gptel-request`
- [x] 6.2 Implement callback interface with success/failure logging
- [x] 6.3 Implement retry logic: API error (429, timeout) does not advance cursor
- [x] 6.4 Implement DLQ logic: malformed output marks processed, appends to errors.org
- [x] 6.5 Verify no module calls `gptel-request` directly

## 7. Router Module (sem-router.el)

- [x] 7.1 Implement headline parsing from `inbox-mobile.org`
- [x] 7.2 Implement `@link` tag detection for URL routing
- [x] 7.3 Implement cursor tracking via `/data/.sem-cursor.el` with content hashes
- [x] 7.4 Route `@link` headlines to `sem-url-capture-process`
- [x] 7.5 Route non-link headlines to LLM task generation
- [x] 7.6 Implement cursor update after successful processing

## 8. URL Capture Module (sem-url-capture.el)

- [x] 8.1 Port `org-roam-url-catcher.el` logic, strip interactive patterns
- [x] 8.2 Implement `sem-url-capture-process` as non-interactive entry point
- [x] 8.3 Implement trafilatura CLI integration for article fetching
- [x] 8.4 Implement LLM prompt building with umbrella node detection
- [x] 8.5 Implement output validation: check `:PROPERTIES:`, `:ID:`, `#+title:`
- [x] 8.6 Implement org-roam node file writing to `/data/org-roam/`
- [x] 8.7 Call `org-roam-db-sync` after successful node write
- [x] 8.8 Implement error handling: trafilatura failure, LLM failure → errors.org
- [x] 8.9 Fix source URL visibility: write URL as first line of `* Summary` section

## 9. RSS Module (sem-rss.el)

- [x] 9.1 Port `tools-rss.el` logic, strip `use-package`, `defcustom`, interactive prompts
- [x] 9.2 Implement `sem-rss-generate-morning-digest` as cron entry point
- [x] 9.3 Port `sem-rss-collect-entries` with 24-hour lookback
- [x] 9.4 Port `sem-rss--format-entry-for-llm` and `sem-rss--build-entries-text`
- [x] 9.5 Port `sem-rss--build-general-prompt` and `sem-rss--build-arxiv-prompt`
- [x] 9.6 Port `sem-rss--generate-file` with silent file write (no `find-file`)
- [x] 9.7 Implement env var reading: `RSS_MAX_ENTRIES_PER_FEED`, `RSS_MAX_INPUT_CHARS`
- [x] 9.8 Write output to `/data/morning-read/YYYY-MM-DD.org` and `YYYY-MM-DD-arxiv.org`
- [x] 9.9 Handle no-entries case: skip file write, no LLM call

## 10. Inbox Processing Integration

- [x] 10.1 Implement headline hash computation for cursor tracking
- [x] 10.2 Implement cursor file read/write (`/data/.sem-cursor.el`)
- [x] 10.3 Implement atomic purge: write temp file, `rename-file` to target
- [x] 10.4 Verify purge only writes at 4AM window
- [x] 10.5 Verify inbox-mobile.org is read-only outside purge window

## 11. Elfeed Integration

- [x] 11.1 Configure elfeed-org to read `/data/feeds.org`
- [x] 11.2 Implement cron schedule: elfeed-update at 5AM, 6AM, 7AM, 8AM
- [x] 11.3 Verify rss-digest runs at 9:30AM (after all updates complete)
- [x] 11.4 Handle missing `/data/feeds.org`: start with empty feed list, no error

## 12. Logging & Error Handling

- [x] 12.1 Verify all modules call `sem-core-log` for structured logging
- [x] 12.2 Verify `sem-core-log-error` writes to both sem-log.org and errors.org
- [x] 12.3 Implement proper log format: timestamp, module, event-type, status, tokens, message
- [x] 12.4 Verify errors.org format: headline, properties, created, input, raw output
- [x] 12.5 Add condition-case wrappers to prevent logging errors from crashing daemon

## 13. Testing & Verification

- [x] 13.1 Test Docker build succeeds with all packages installed
- [x] 13.2 Test daemon startup with valid `.env` configuration
- [x] 13.3 Test daemon aborts with missing/empty `OPENROUTER_KEY` or `OPENROUTER_MODEL`
- [x] 13.4 Test inbox processing with sample headlines
- [x] 13.5 Test URL capture with trafilatura integration
- [x] 13.6 Test RSS digest generation with sample feed entries
- [x] 13.7 Test atomic purge with crash simulation
- [x] 13.8 Test Elfeed DB corruption recovery
- [x] 13.9 Test org-roam DB rebuild on startup
- [x] 13.10 Test `*Messages*` persistence to host mount
- [x] 13.11 Test security masking with sensitive blocks
- [x] 13.12 Test URL sanitization in appropriate outputs only

## 14. Documentation

- [x] 14.1 Write deployment guide: clone, `.env` setup, `mkdir -p logs`, `docker-compose up`
- [x] 14.2 Document log rotation setup with logrotate
- [x] 14.3 Document error recovery workflow (manual inspection of errors.org)
- [x] 14.4 Document rollback strategy: stop, git revert, rebuild
- [x] 14.5 Add `.gitignore` for `./logs/`, `.env`, `straight/` (except lockfile)
- [x] 14.6 Create `LICENSE` file at repository root containing the full GPL-3.0 license text
- [x] 14.7 Add GPL-3.0 SPDX header block to every `.el` file: `bootstrap-packages.el`, `init.el`, `sem-core.el`, `sem-security.el`, `sem-llm.el`, `sem-router.el`, `sem-url-capture.el`, `sem-rss.el`, and all files under `/app/elisp/tests/`

## 15. ERT Test Suite

- [x] 15.1 Create `/app/elisp/tests/sem-mock.el` with reusable mock helpers: `sem-mock-gptel-request-success`, `sem-mock-gptel-request-error`, `sem-mock-trafilatura-success`, `sem-mock-trafilatura-failure`, `sem-mock-org-roam-db-query`
- [x] 15.2 Create `/app/elisp/tests/sem-core-test.el`: test `sem-core-log` format (with/without tokens field), cursor read/write round-trip, content hash determinism
- [x] 15.3 Create `/app/elisp/tests/sem-security-test.el`: test tokenize/detokenize round-trip, sensitive block content not present in tokenized string, URL sanitization applied/not-applied
- [x] 15.4 Create `/app/elisp/tests/sem-router-test.el`: test `@link` routing to url-capture, `@task` routing to LLM pipeline, unknown tag skip, already-processed hash skip, URL extraction from headline title
- [x] 15.5 Create `/app/elisp/tests/sem-rss-test.el`: test `sem-rss--clean-text` HTML stripping/entity replacement/truncation, `sem-rss--build-entries-text` total truncation, prompt builders contain category names, `sem-rss-collect-entries` per-feed cap
- [x] 15.6 Create `/app/elisp/tests/sem-url-capture-test.el`: test `sem-url-capture--sanitize-text` (digit-only lines, whitespace, truncation), `sem-url-capture--make-slug` (downcase, non-alphanum strip, 50-char limit), `sem-url-capture--validate-and-save` errors on missing `:PROPERTIES:` and `#+title:`, prompt builder output contains `Source: [[URL][URL]]` as first line of `* Summary`
- [x] 15.7 Create `/app/elisp/tests/sem-llm-test.el`: test API error → hash NOT added to cursor, malformed output → hash added to cursor + `sem-core-log-error` called, valid response → success callback invoked
- [x] 15.8 Create `/app/elisp/tests/sem-test-runner.el`: `(require ...)` all test files in dependency order, no other logic; verify `docker run` command exits 0 with all tests passing
- [x] 15.9 Verify all ERT tests complete in under 30 seconds with no real network or LLM calls

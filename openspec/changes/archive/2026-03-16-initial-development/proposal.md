## Why

The user captures notes, tasks, and links on mobile via Orgzly. These accumulate in `inbox-mobile.org` with no automated triage. Processing them into GTD-structured tasks requires manual Emacs intervention, which defeats the purpose of mobile capture. The system must autonomously process the inbox via LLM, generate morning digests from RSS/arXiv, and write structured output — all without user intervention and without corrupting the Org file the mobile client is actively syncing.

## What Changes

A new self-hosted system is introduced from scratch. No existing codebase is modified. The system consists of two Docker containers (WebDAV server, Emacs daemon) sharing a single data volume, orchestrated via `docker-compose`, deployed to a public VPS with Caddy handling TLS via Let's Encrypt.

Two existing Emacs Lisp files (`tools-rss.el`, `org-roam-url-catcher.el`) are ported and integrated as daemon modules. They are not used as-is: all interactive patterns (`use-package`, `defcustom`, `y-or-n-p`, `read-number`, `find-file`) are stripped and replaced with `.env`-driven configuration and non-interactive daemon-safe equivalents.

## Capabilities

### New Capabilities

- `webdav-sync`: Expose `/data` volume over WebDAV with HTTP Basic Auth. Orgzly connects to this endpoint to sync Org files. Constraint: must support concurrent reads/writes from Orgzly without corrupting files. Constraint: credentials must be configured via `.env`, never hardcoded. Constraint: Emacs lock files (`create-lockfiles nil`) must be disabled to prevent WebDAV sync failures.

- `inbox-processing`: Every 30 minutes, read unprocessed headlines from `/data/inbox-mobile.org`, pass them through the LLM, and write structured Org output to `/data/tasks.org`. If `/data/inbox-mobile.org` does not exist when the cron job fires, log a warning to `/data/sem-log.org` and exit cleanly — the daemon does not create this file. Orgzly is the sole creator of `/data/inbox-mobile.org`. If `/data/tasks.org` does not exist, it is created on first write. Headlines tagged `@link` are routed to `url-capture` instead of the task LLM pipeline; the URL is the bare headline title text (e.g., `* https://example.com :@link:`). `sem-router.el` extracts the URL directly from the headline title string. Constraint: `inbox-mobile.org` is **read-only at all times except the 4AM purge window** — no LLM output is ever written back to it. Constraint: processed node identity is tracked via `/data/.sem-cursor.el` using content hashes; a node is marked processed only after successful output is written. Constraint: on LLM API error (`429`, timeout), the node hash is NOT added to the cursor — it retries on next cron run. Constraint: on malformed LLM output (non-valid Org), the raw response and original input are appended to `/data/errors.org` (Dead Letter Queue) and the node is marked processed to prevent infinite retry loops.

- `url-capture`: When `inbox-processing` routes a `@link` headline, `sem-router.el` calls `sem-url-capture-process` which runs the full pipeline: fetch full article text via `trafilatura` CLI, sanitize for token efficiency, query org-roam DB for umbrella nodes, send to LLM, validate output, and write a new org-roam node file to `/data/org-roam/`. `sem-url-capture-process` returns the saved filepath on success or `nil` on any failure. The calling code in `sem-router.el` / `inbox-processing` is responsible for marking the headline processed in `.sem-cursor.el` regardless of whether `url-capture` returned a filepath or nil — the headline is never retried after the url-capture pipeline has been invoked (errors are in `errors.org`). Constraint: `trafilatura` must be installed in the Emacs container (Python + pip dependency; must be declared in the container's Dockerfile). Constraint: if `trafilatura` exits non-zero or returns empty content, the error is appended to `/data/errors.org` and `nil` is returned. Constraint: LLM output is validated for presence of `:PROPERTIES:`, `:ID:`, and `#+title:` before saving; invalid output goes to `/data/errors.org`. Constraint: `org-roam-db-sync` is called after each successful node write. Constraint: org-roam directory is `/data/org-roam/`; this path is hardcoded in `init.el`, not configurable at runtime.

- `inbox-purge`: At 4:00 AM daily, remove all nodes from `/data/inbox-mobile.org` whose hashes appear in `/data/.sem-cursor.el`. This is the **only** time window in which `/data/inbox-mobile.org` is written. Constraint: purge must be atomic — the implementation must write the purged content to a temporary file (e.g., `/data/.inbox-mobile.org.tmp`), then call `(rename-file tmp-path "/data/inbox-mobile.org" t)`. `rename-file` is atomic on POSIX filesystems. Direct in-place buffer save or `write-region` to the target path is forbidden. A crash before `rename-file` completes leaves the original file untouched.

- `elfeed-update`: Elfeed database is refreshed four times before digest generation to ensure fresh feed content. Cron schedule: `0 5 * * *`, `0 6 * * *`, `0 7 * * *`, `0 8 * * *` — one `emacsclient -e "(elfeed-update)"` call per hour from 5AM to 8AM. Constraint: `elfeed-update` is always called via `emacsclient`, never via an internal Emacs timer. Constraint: no digest generation may be triggered before 8AM — the two capabilities (update and digest) use separate, non-overlapping cron entries. Constraint: feed subscription list is read from `/data/feeds.org` via elfeed-org. If `/data/feeds.org` does not exist at `elfeed-update` time, elfeed starts with an empty feed list — no error is raised, no fallback file is created.

- `rss-digest`: At 9:30 AM daily (`30 9 * * *`), fetch and process entries already in the Elfeed database (populated by `elfeed-update` runs at 5–8AM) from the last 24 hours via LLM and write digests to `/data/morning-read/YYYY-MM-DD.org` (general) and `/data/morning-read/YYYY-MM-DD-arxiv.org` (arXiv). Ported from `tools-rss.el`. Constraint: `rss-digest` reads the **local Elfeed DB only** — it does not call `elfeed-update` itself. Constraint: lookback window is always exactly 24 hours — no interactive parameter. Constraint: per-feed entry cap and max input token limit are set via `.env` vars (`RSS_MAX_ENTRIES_PER_FEED`, `RSS_MAX_INPUT_CHARS`); defaults apply if unset. Constraint: if no entries are found for a filter, no file is written and no LLM call is made.

- `security-masking`: Before any content is sent to the LLM API, all `#+begin_sensitive` / `#+end_sensitive` blocks must be replaced with opaque tokens and restored in output before writing to disk. Constraint: this is a **hard requirement** — no content between sensitive blocks may ever reach the LLM API. Constraint: URL sanitization (`http://` → `hxxp://`, `https://` → `hxxps://`) applies **only** to `inbox-processing` output (`/data/tasks.org`) and `rss-digest` output (`/data/morning-read/`). URL sanitization is **explicitly excluded** from `url-capture` output written to `/data/org-roam/` — real URLs are required for `#+ROAM_REFS` and `[[link]]` anchors; sanitizing them would break org-roam. Constraint: local variable blocks in Org files must be disabled (`enable-local-variables nil`) to prevent malicious RSS payloads from re-enabling org-babel evaluation.

- `cron-scheduling`: System cron inside the Emacs container drives all timed execution via `emacsclient`. The crontab is committed to the repository as a file and installed into the container image via `COPY` + `crontab /etc/cron.d/sem-cron` in the Dockerfile. Changing the schedule requires a container rebuild. The complete schedule, with no gaps or overlaps, is:

  ```
  */30 * * * *  root  emacsclient -e "(sem-core-process-inbox)"
  0    4 * * *  root  emacsclient -e "(sem-core-purge-inbox)"
  0    5 * * *  root  emacsclient -e "(elfeed-update)"
  0    6 * * *  root  emacsclient -e "(elfeed-update)"
  0    7 * * *  root  emacsclient -e "(elfeed-update)"
  0    8 * * *  root  emacsclient -e "(elfeed-update)"
  30   9 * * *  root  emacsclient -e "(sem-rss-generate-morning-digest)"
  ```

  Constraint: Emacs internal timers (`run-at-time`, `idle-timer`) must not be used for scheduled tasks. Constraint: each cron invocation must be independent — a crash in one execution must not affect the next. Constraint: the 4AM purge and the `*/30` inbox-processing share the same time domain — the cron daemon serializes them; no locking is required between them.

- `db-initialization`: On every daemon startup, `init.el` runs a bootstrap check for both the Elfeed DB and the org-roam DB. This runs once, synchronously, before the daemon accepts any `emacsclient` connections.

  **First-run / pre-populated data**: If the operator has pre-populated `/data/org-roam/` with existing `.org` files before the first container start (e.g., by cloning a GitHub repo containing existing notes into `/data/org-roam/` on the VPS), these files are automatically discovered and indexed by `org-roam-db-sync` during this step. No manual intervention is required. The system treats any `.org` files present in `/data/org-roam/` at startup as legitimate notes regardless of their origin. Similarly, if `/data/feeds.org` is pre-placed (e.g., copied from an existing Orgzly/Nextcloud setup), it is picked up by elfeed-org immediately. The operator's only responsibility is to ensure files are present in `/data/` before `docker-compose up`.

  **Elfeed**: attempt `(elfeed-db-load)`. If it succeeds, keep the existing DB — entries fetched before a container restart are preserved. If it raises an error (corrupt DB), delete `/data/elfeed/` entirely and call `(elfeed-db-load)` again to create a fresh empty DB. Configure elfeed-org to read `/data/feeds.org`; if `/data/feeds.org` does not exist, elfeed starts with an empty feed list — no error.

  **org-roam**: always delete `/data/org-roam/org-roam.db` (and `*.db-shm`, `*.db-wal`) if they exist, then call `(org-roam-db-sync)` to rebuild from all `.org` files in `/data/org-roam/`. The DB is always rebuilt because it is deterministically derived from `.org` files — rebuilding is safe and idempotent regardless of whether files were pre-placed or daemon-generated. If `/data/org-roam/` is empty or does not exist, `org-roam-db-sync` produces an empty DB — no error.

  Constraint: if `org-roam-db-sync` raises an error (e.g., malformed `.org` file), log to `/data/errors.org` and continue — the daemon must not abort due to a corrupt note file. Constraint: Elfeed DB is **never proactively wiped** — only wiped on proven corruption.

- `messages-redirection`: The Emacs `*Messages*` buffer accumulates all `message` calls including Emacs internals, package warnings, and cron callback output. In a headless daemon this buffer is lost on container restart. It must be durably persisted outside the `/data` volume to a dedicated host-mounted log directory, so it survives container crashes and volume replacements independently.

  Implementation:
  - docker-compose declares a second host mount on the Emacs container: `./logs:/var/log/sem:rw`. The `./logs/` directory lives next to `docker-compose.yml` in the repository root on the VPS host — outside `/data`. It is gitignored.
  - `init.el` redirects `*Messages*` to this directory by adding a hook:
    ```elisp
    (defun sem-core--flush-messages ()
      "Append *Messages* buffer content to the durable log file."
      (let ((log-path "/var/log/sem/messages.log")
            (content (with-current-buffer "*Messages*"
                       (buffer-string))))
        (write-region content nil log-path t 'silent)))
    (add-hook 'post-command-hook #'sem-core--flush-messages)
    ```
  - `post-command-hook` fires after every `emacsclient` invocation, flushing accumulated messages. The `t` argument to `write-region` appends rather than overwrites. `'silent` suppresses echo.
  - Constraint: `messages.log` is never rotated by the daemon — rotation is the operator's responsibility (e.g., `logrotate` on the host). Constraint: the `./logs/` directory must exist on the host before `docker-compose up` — `docker-compose` does not create host-side bind mount directories on all platforms. Add to deployment docs: `mkdir -p logs` before first run.
  - Constraint: `sem-core--flush-messages` must be wrapped in `condition-case` — it must never crash the daemon if `/var/log/sem/` is unwritable.

- `structured-logging`: All modules write structured log entries to `/data/sem-log.org` via `sem-core-log`. This file is valid Org-mode, readable directly in Orgzly. The file structure is:

  ```
  * YYYY
  ** YYYY-MM (Month Name)
  *** YYYY-MM-DD Day
  - [HH:MM:SS] [MODULE] [EVENT-TYPE] [STATUS] tokens=NNN | message
  ```

  Exact field definitions — a junior must match these precisely:
  - `HH:MM:SS`: 24-hour local time of the daemon container (UTC).
  - `MODULE`: one of `core`, `router`, `rss`, `url-capture`, `security`, `llm`, `elfeed`, `purge`, `init`.
  - `EVENT-TYPE`: one of `INBOX-ITEM`, `URL-CAPTURE`, `RSS-DIGEST`, `ARXIV-DIGEST`, `ELFEED-UPDATE`, `PURGE`, `STARTUP`, `ERROR`.
  - `STATUS`: one of `OK`, `RETRY`, `DLQ`, `SKIP`, `FAIL`.
  - `tokens=NNN`: approximate input character count divided by 4 (integer, no decimals). If no LLM call was made, omit this field entirely.
  - `message`: free-form string, no newlines, max 200 characters.

  Example entries:
  ```
  - [09:31:02] [rss] [RSS-DIGEST] [OK] tokens=12450 | general digest written to /data/morning-read/2026-03-16.org
  - [09:31:45] [rss] [ARXIV-DIGEST] [SKIP] | no entries found for arxiv filter
  - [04:00:01] [purge] [PURGE] [OK] | removed 7 nodes from inbox-mobile.org
  - [05:00:00] [elfeed] [ELFEED-UPDATE] [OK] | elfeed-update completed
  - [00:30:02] [router] [INBOX-ITEM] [DLQ] tokens=320 | malformed LLM output, sent to errors.org. title=Buy milk
  - [00:30:03] [url-capture] [URL-CAPTURE] [RETRY] | trafilatura failed exit=1. url=https://example.com
  ```

  Constraint: `sem-core-log` must create `/data/sem-log.org` and all required heading levels if they do not exist. Constraint: each call to `sem-core-log` appends exactly one list item under the correct `*** YYYY-MM-DD` heading, creating intermediate headings as needed. Constraint: `sem-core-log-error` calls `sem-core-log` with `STATUS=FAIL` or `STATUS=DLQ` AND appends the raw error detail to `/data/errors.org`. Constraint: `sem-core-log` must never raise an error itself — wrap all file I/O in `condition-case` and fall back to `message` if the log file is unwritable.

  `/data/errors.org` format — a junior must match this exactly. Each error entry is a top-level headline:
  ```
  * [YYYY-MM-DD HH:MM:SS] [MODULE] [EVENT-TYPE] FAIL
  :PROPERTIES:
  :CREATED: [YYYY-MM-DD HH:MM:SS]
  :END:
  Error: <error message string>

  ** Input
  <original input text or URL that caused the failure>

  ** Raw LLM Output
  <raw LLM response, or "N/A" if LLM was not called>
  ```
  Constraint: `errors.org` is append-only — entries are never deleted or modified by the daemon. Constraint: `sem-core-log-error` is the sole writer of `errors.org` — no module writes to it directly.

- `sem-llm`: `sem-llm.el` is the LLM integration module. It wraps `gptel-request` with a standard callback interface used by `sem-router.el`, `sem-rss.el`, and `sem-url-capture.el`. It handles the `condition-case` wrapper for all LLM callbacks, calls `sem-core-log` on success/failure, and enforces the retry-vs-DLQ decision (API error → do not mark processed; malformed output → mark processed and DLQ). No module may call `gptel-request` directly — all LLM calls must go through `sem-llm.el`.

- `emacs-package-provisioning`: All required Emacs packages are installed at container image build time using `straight.el`. A `straight/versions/default.el` lockfile is committed to the repository at `/app/elisp/straight/versions/default.el`, pinning exact package revisions. A dedicated `/app/elisp/bootstrap-packages.el` file (separate from `init.el`) contains only straight.el bootstrapping and package installation logic. The Dockerfile installs packages with the following RUN step:
  ```dockerfile
  RUN emacs --batch --no-site-file \
      --load /app/elisp/bootstrap-packages.el
  ```
  `bootstrap-packages.el` must: (1) bootstrap straight.el from its own GitHub release, (2) load the lockfile via `straight-use-package`, (3) install `gptel`, `elfeed`, `elfeed-org`, `org-roam`, `websocket` using `(straight-use-package 'PKG)`. This file is committed to the repo. No package installation occurs at container runtime — `init.el` only calls `(require ...)`, never `straight-use-package`. Constraint: the lockfile must be committed and must not be `.gitignore`d. Constraint: if a package fails to install during build, the Docker build must fail — do not silently continue with missing packages. Constraint: `bootstrap-packages.el` must not load `init.el` or any `sem-*.el` module — it installs packages only.

- `gptel-configuration`: gptel is configured in `init.el` to use OpenRouter as the backend. Constraint: the API key must be provided as a lambda wrapping `getenv` — never as a hardcoded string. Constraint: the model must be read from the `OPENROUTER_MODEL` environment variable at call time — never hardcoded in Elisp. Constraint: `OPENROUTER_KEY` and `OPENROUTER_MODEL` are declared in `.env` and passed to the Emacs container via docker-compose `environment:` block. Constraint: if either variable is unset or empty at runtime, `init.el` must signal an error and abort daemon startup. Constraint: `gptel-backend` and `gptel-model` must be set as globals in `init.el` immediately after `gptel-make-openai` so all modules use the configured backend without re-specifying it. The required configuration pattern in `init.el` is:

  ```elisp
  (gptel-make-openai "OpenRouter"
    :host "openrouter.ai"
    :endpoint "/api/v1/chat/completions"
    :stream t
    :key (lambda () (getenv "OPENROUTER_KEY"))
    :models (list (intern (getenv "OPENROUTER_MODEL"))))
  (setq gptel-backend (gptel-get-backend "OpenRouter"))
  (setq gptel-model (intern (getenv "OPENROUTER_MODEL")))
  ```

- `github-sync-readiness`: The system is structured so that a future `github-integration` capability can be added without architectural changes. Pre-wiring requirements (all implemented now, integration deferred):
  1. `/data/org-roam/` is a git repository. During `db-initialization`, after `org-roam-directory` is set, `init.el` checks if `/data/org-roam/.git/` exists. If not, it runs `(call-process "git" nil nil nil "init" "/data/org-roam/")` and writes `/data/org-roam/.gitignore` with entries: `org-roam.db`, `*.db-shm`, `*.db-wal`. The SQLite DB is never committed. This runs before `org-roam-db-sync`.
  2. A read-only SSH credentials volume is declared in docker-compose for the Emacs container: `~/.ssh/vps-org-roam:/root/.ssh:ro`. Currently empty/unused. When github-integration is added, the operator places an SSH key here and configures the git remote — no Dockerfile or compose change required.
  3. The daemon's write contract is: **daemon only ever creates new `.org` files in `/data/org-roam/` — it never modifies or deletes existing ones**. This is a hard constraint. It ensures git history is append-only from the VPS side, minimizing merge conflicts with laptop edits. Laptop-side edits committed and pushed to the same repo are the only other write path.
  4. Sync direction: VPS pushes new nodes to GitHub. Laptop pulls from GitHub. Laptop may also push edits. Merge conflicts are possible if the user edits a node on the laptop while the daemon writes a new node. This risk is accepted and documented. Conflict resolution is out of scope.

### Modified Capabilities

_(none — this is a greenfield system)_

## Daemon Startup Sequence

`init.el` must execute the following steps in strict order. Any deviation in ordering is a bug.

1. **Validate required env vars**: check `OPENROUTER_KEY` and `OPENROUTER_MODEL` are non-empty. If either is absent, signal an error and abort — the daemon must not start without LLM credentials.
2. **Configure gptel**: call `gptel-make-openai` with OpenRouter settings (see `gptel-configuration`). Set `gptel-backend` and `gptel-model` globals.
3. **Set all hardcoded paths as globals**: `org-roam-directory` → `/data/org-roam/`, `elfeed-db-directory` → `/data/elfeed/`, `rmh-elfeed-org-files` → `'("/data/feeds.org")`.
4. **Set security globals**: `(setq create-lockfiles nil)`, `(setq enable-local-variables nil)`, `(setq org-confirm-babel-evaluate t)`, `(setq org-export-babel-evaluate nil)`, `(setq org-display-remote-inline-images nil)`.
5. **Initialize git repo for org-roam** (see `github-sync-readiness`): if `/data/org-roam/.git/` does not exist, run `git init` and write `.gitignore`.
6. **Run db-initialization** (see `db-initialization`): conditionally handle Elfeed DB, always rebuild org-roam DB.
7. **Load all modules** (packages already installed in image) in this exact order — `sem-core` must load first as it defines `sem-core-log` which all other modules call at load time: `(require 'sem-core)`, `(require 'sem-security)`, `(require 'sem-llm)`, `(require 'sem-rss)`, `(require 'sem-url-capture)`, `(require 'sem-router)`. `sem-router` loads last because it depends on all other modules being ready.
8. **Install `*Messages*` redirection hook**: add `sem-core--flush-messages` to `post-command-hook` (see `messages-redirection`).
9. **Daemon ready**: accepts `emacsclient` connections.

## File Placement & Porting Instructions

The following existing files must be ported (not copied as-is) into the module structure at `/app/elisp/`:

### `tools-rss.el` → `/app/elisp/sem-rss.el`

**Strip:**
- All `use-package` blocks (elfeed, elfeed-org). Package loading is handled by `init.el`.
- All `defcustom` / `defgroup` declarations.
- All interactive functions (`my/get-morning-read`, `my/get-morning-arxiv`, `my/rss--run-logic` interactive prompts: `y-or-n-p`, `read-number`, `find-file`).

**Replace with:**
- Configuration values read from environment variables at module load time: `RSS_MAX_ENTRIES_PER_FEED` (default: 10), `RSS_MAX_INPUT_CHARS` (default: 199000), `RSS_DIR` (hardcoded: `/data/morning-read/`). Model is not re-specified here — `gptel-model` global set in `init.el` is used.
- A single non-interactive entry point `sem-rss-generate-morning-digest` callable by cron via `emacsclient -e "(sem-rss-generate-morning-digest)"`. It runs both general and arxiv digest generation sequentially. Lookback is always 24 hours (1 day).
- Replace `find-file` (opens buffer for user) with silent file write only.
- Replace `message` calls used for UI with `sem-core-log` (to be defined in `sem-core.el`).

**Retain (logic is correct and reusable):**
- `my/rss--clean-text` → rename to `sem-rss--clean-text`.
- `my/rss-collect-entries` → rename to `sem-rss-collect-entries`.
- `my/rss--format-entry-for-llm` → rename to `sem-rss--format-entry-for-llm`.
- `my/rss--build-entries-text` → rename to `sem-rss--build-entries-text`.
- `my/rss--build-general-prompt` → rename to `sem-rss--build-general-prompt`.
- `my/rss--build-arxiv-prompt` → rename to `sem-rss--build-arxiv-prompt`.
- `my/rss--generate-file` → rename to `sem-rss--generate-file`; remove `find-file` call at end of callback.
- Category alists (`my-rss-categories`, `my-rss-arxiv-categories`) become module-level `defconst` (not customizable).

### `org-roam-url-catcher.el` → `/app/elisp/sem-url-capture.el`

**Strip:**
- `defcustom my/url-catcher-max-chars` and `defcustom my/url-catcher-umbrella-tag` — replace with constants or env vars.
- All interactive entry point `my/collect-url` (replaced by programmatic call from `sem-router.el`).
- `display-buffer` / `get-buffer-create` for error display — replace with append to `/data/errors.org`.

**Replace with:**
- A non-interactive function `sem-url-capture-process (url headline-plist)` callable from `sem-router.el`. It runs the full pipeline and returns the saved filepath or nil on failure.
- Error handling: on any failure (trafilatura non-zero, validation failure, LLM error), append raw content + error message to `/data/errors.org` and return nil. Do not display buffers.
- `org-roam-directory` is set to `/data/org-roam/` in `init.el`; do not override it in this module.
- **Source URL visibility fix**: `#+ROAM_REFS` is not rendered visibly in org-roam-ui's node preview. The source URL must appear as the **first line of the `* Summary` section body** as a plain org-mode link: `Source: [[URL][URL]]`. This makes it visible in org-roam-ui's preview panel. `#+ROAM_REFS` is still written (it is used by org-roam for backlink resolution), but it is not the primary display mechanism. The `sem-url-capture--build-user-prompt` function must update the `EXPECTED OUTPUT FORMAT` section to enforce this structure:
  ```
  * Summary
  Source: [[ARTICLE_URL][ARTICLE_URL]]
  <brief summary text>
  ```
  The system prompt in `sem-url-capture--build-system-prompt` must explicitly state: "The first line of the `* Summary` section must always be `Source: [[URL][URL]]` using the exact article URL."

**Retain (logic is correct and reusable):**
- `my/url-catcher--fetch-url` → rename to `sem-url-capture--fetch-url`. Keep `executable-find "trafilatura"` guard.
- `my/url-catcher--sanitize-text` → rename to `sem-url-capture--sanitize-text`.
- `my/url-catcher--get-umbrella-nodes` → rename to `sem-url-capture--get-umbrella-nodes`.
- `my/url-catcher--build-system-prompt` → rename to `sem-url-capture--build-system-prompt`.
- `my/url-catcher--build-user-prompt` → rename to `sem-url-capture--build-user-prompt`.
- `my/url-catcher--make-slug` → rename to `sem-url-capture--make-slug`.
- `my/url-catcher--validate-and-save` → rename to `sem-url-capture--validate-and-save`. Replace `org-roam-db-sync` call with `(org-roam-db-sync)` (unchanged, already correct).
- `my/url-catcher--pipeline-callback` → rename to `sem-url-capture--pipeline-callback`. Replace `my/url-catcher--show-error` calls with `sem-core-log-error` appending to `/data/errors.org`.

## Impact

- **New infrastructure**: Two new Docker containers introduced. Requires `docker` and `docker-compose` on the host VPS. Requires ports 80/443 open for Caddy Let's Encrypt TLS.
- **Emacs packages baked into image**: `straight.el` lockfile committed to repo. All packages (`gptel`, `elfeed`, `elfeed-org`, `org-roam`, `websocket`) installed at `docker build` time. Image build requires internet access. No runtime package fetching.
- **Log file**: `/data/sem-log.org` is created and maintained by the daemon. Readable in Orgzly as a structured Org file. `/data/errors.org` is the DLQ for failed/malformed processing items.
- **Messages log**: `./logs/messages.log` on the VPS host (bind-mounted at `/var/log/sem/` in the container). Persists across container restarts and volume replacements. Operator must run `mkdir -p logs` before first `docker-compose up`. Gitignored.
- **New Python dependency**: The Emacs container Dockerfile must install Python 3, pip, and `trafilatura` (`pip install trafilatura`). This adds to image build time and image size.
- **New secrets**: `.env` file required with `OPENROUTER_KEY`, `OPENROUTER_MODEL`, `WEBDAV_USER`, `WEBDAV_HASH`, `PUID`, `PGID`. Optional: `RSS_MAX_ENTRIES_PER_FEED`, `RSS_MAX_INPUT_CHARS`. `OPENROUTER_KEY` and `OPENROUTER_MODEL` are **required** — daemon aborts on startup if either is absent. Must not be committed to version control.
- **Shared volume dependency**: Both containers depend on the `/data` volume. Volume loss equals loss of all Org files, org-roam DB, and cursor state.
- **org-roam required**: The Emacs container must have `org-roam` installed. DB is initialized automatically on every daemon startup (see `db-initialization` capability). No manual first-run step required.
- **No existing systems modified**: This proposal does not touch any pre-existing infrastructure or codebase. The source files `tools-rss.el` and `org-roam-url-catcher.el` in the repo root are reference copies only; they are not loaded by the daemon.
- **SSH volume pre-wired**: docker-compose declares `~/.ssh/vps-org-roam:/root/.ssh:ro` on the Emacs container. Empty at this stage. Required for future github-integration without compose changes.
- **org-roam git repo pre-initialized**: `/data/org-roam/` is a git repo from first startup. `.gitignore` excludes all SQLite DB files. No remote is configured at this stage.
- **Out of scope**: Backup/restore of `/data`, multi-user WebDAV, LLM model selection UI, mobile client configuration, elfeed DB seeding from external OPML, org-roam-ui static site publishing (planned via GitHub Actions in a future change), git remote configuration, SSH key provisioning, laptop-side org-roam-db-sync automation after pull.
- **Log rotation**: `./logs/messages.log` on the VPS host is not managed by the daemon. Out of scope.

## Testing

### Philosophy

Tests use ERT (Emacs Lisp Regression Testing) with `cl-letf` mocks. **No test may make a real network call, real LLM call, or write to `/data/`.** All file I/O in tests uses `with-temp-buffer` or a `temp-directory` created and deleted within the test. All `gptel-request` calls must be mocked.

Use `cl-assert` for inline invariant checks within production functions where a violated assumption indicates a bug (e.g., a nil URL reaching `sem-url-capture--fetch-url`). Use `ert-deftest` + `should` / `should-not` / `should-error` for all test definitions. Do not mix `cl-assert` and `should` — `cl-assert` is for production guards, `should` is for tests only.

### Test File Structure

All test files live at `/app/elisp/tests/`:

```
/app/elisp/tests/
├── sem-test-runner.el      # Entry point: loads all test files, runs all tests
├── sem-security-test.el    # Tests for sem-security.el
├── sem-router-test.el      # Tests for sem-router.el
├── sem-rss-test.el         # Tests for sem-rss.el (prompt builders, text cleaning, entry filtering)
├── sem-url-capture-test.el # Tests for sem-url-capture.el (sanitize, slug, validate, prompt)
├── sem-llm-test.el         # Tests for sem-llm.el (retry/DLQ logic, callback dispatch)
├── sem-core-test.el        # Tests for sem-core.el (log format, cursor read/write, hash)
└── sem-mock.el             # Shared mocks: gptel-request, trafilatura, org-roam-db-query
```

### What Must Be Tested (mandatory coverage — no exceptions)

**`sem-security-test.el`**
- `sem-tokenize-sensitive-block` replaces `#+begin_sensitive...#+end_sensitive` content with a `{{SEC_ID_...}}` token; the original text does not appear in the returned string.
- `sem-detokenize-sensitive-block` restores the original text exactly, given the same token map.
- `sem-sanitize-urls` replaces `http://` with `hxxp://` and `https://` with `hxxps://` in a string.
- `sem-sanitize-urls` does NOT alter strings containing no URLs.
- Tokenization round-trip: tokenize then detokenize returns the original string unchanged.

**`sem-router-test.el`**
- A headline with tag `@link` and a bare URL title is routed to `url-capture`, not the task LLM pipeline.
- A headline with tag `@task` is routed to the task LLM pipeline.
- A headline with no known tag is skipped (logged, not processed).
- A headline whose hash already exists in the cursor is skipped without calling the LLM.
- URL extraction from an `@link` headline title returns the exact URL string.

**`sem-rss-test.el`**
- `sem-rss--clean-text` strips `<script>`, `<style>`, and all HTML tags from input.
- `sem-rss--clean-text` replaces `&nbsp;`, `&amp;`, `&quot;` with their text equivalents.
- `sem-rss--clean-text` truncates output to 3000 characters and appends `...`.
- `sem-rss--build-entries-text` truncates total output to `RSS_MAX_INPUT_CHARS`.
- `sem-rss--build-general-prompt` output contains the category names from the `defconst` alist.
- `sem-rss--build-arxiv-prompt` output contains the arXiv category names from the `defconst` alist.
- `sem-rss-collect-entries` respects `my-rss-max-entries-per-feed` cap per feed.

**`sem-url-capture-test.el`**
- `sem-url-capture--sanitize-text` removes digit-only lines, single-char lines, collapses whitespace, and truncates to `my/url-catcher-max-chars`.
- `sem-url-capture--make-slug` downcases, strips non-alphanumeric, trims hyphens, truncates to 50 chars.
- `sem-url-capture--validate-and-save` returns an error condition when `:PROPERTIES:` is absent.
- `sem-url-capture--validate-and-save` returns an error condition when `#+title:` is absent.
- `sem-url-capture--build-user-prompt` output contains `Source: [[URL][URL]]` as the first line of the `* Summary` section.
- `sem-url-capture--build-system-prompt` output contains the literal string `Source: [[URL][URL]]`.

**`sem-llm-test.el`**
- On simulated API error (mocked `gptel-request` returning nil response with `:error` in info plist): `sem-llm` does NOT add the node hash to the cursor.
- On simulated malformed output (mocked response is plain text, not valid Org): `sem-llm` adds the node hash to the cursor (DLQ path) and calls `sem-core-log-error`.
- On simulated valid response: `sem-llm` calls the success callback with the response string.

**`sem-core-test.el`**
- `sem-core-log` writes exactly one list item to a temp file matching the format `- [HH:MM:SS] [MODULE] [EVENT-TYPE] [STATUS] ... | message`.
- `sem-core-log` with a `tokens` argument includes `tokens=NNN` in the output.
- `sem-core-log` without a `tokens` argument omits `tokens=` entirely.
- Cursor read/write round-trip: write a set of hashes to `.sem-cursor.el`, read them back, result is `equal` to the original set.
- Content hash of a headline string is deterministic: same input always produces the same hash.

### Mocks (`sem-mock.el`)

`sem-mock.el` must define the following reusable mock helpers using `cl-letf`:

- `sem-mock-gptel-request-success (response-string)` — replaces `gptel-request` with a function that immediately calls the `:callback` with `response-string` and a nil info plist.
- `sem-mock-gptel-request-error (error-keyword)` — replaces `gptel-request` with a function that calls `:callback` with `nil` response and `(list :error error-keyword)` info.
- `sem-mock-trafilatura-success (content-string)` — replaces `call-process` for `trafilatura` with a function that writes `content-string` to the output buffer and returns exit code `0`.
- `sem-mock-trafilatura-failure ()` — replaces `call-process` for `trafilatura` to return exit code `1` with empty output.
- `sem-mock-org-roam-db-query (rows)` — replaces `org-roam-db-query` to return `rows` without hitting the DB.

### Single Entry Point

The operator runs all tests before deploying with one command executed on the VPS host (or locally with Docker):

```bash
docker run --rm \
  -v "$(pwd)/app/elisp:/app/elisp:ro" \
  sem-emacs \
  emacs --batch --no-site-file \
    -L /app/elisp \
    -L /app/elisp/tests \
    --load /app/elisp/tests/sem-test-runner.el \
    --funcall ert-run-tests-batch-and-exit
```

`sem-test-runner.el` must `(require ...)` every test file in dependency order and call nothing else. Exit code `0` = all tests pass. Exit code non-zero = at least one failure. The CI/CD pipeline (future) hooks into this exit code. Constraint: this command must work against the same Docker image used in production — no special test image. Constraint: tests must complete in under 30 seconds — no blocking network calls.

## License

This project is licensed under **GPL-3.0**. Every `.el` source file must include the following header comment block:

```elisp
;; Copyright (C) 2026 sem
;; SPDX-License-Identifier: GPL-3.0-or-later
;;
;; This file is part of sem-assistant-el.
;;
;; sem-assistant-el is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
```

A `LICENSE` file containing the full GPL-3.0 text must be present at the repository root. Constraint: no source file may be committed without the SPDX header. Constraint: the license applies to all `.el` files including `bootstrap-packages.el`, `init.el`, and all test files.

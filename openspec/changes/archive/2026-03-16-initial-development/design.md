## Context

This is a greenfield system that processes mobile-captured Org notes and RSS feeds autonomously via LLM. The system runs as two Docker containers (WebDAV server + Emacs daemon) sharing a `/data` volume, deployed to a public VPS with TLS via Caddy/Let's Encrypt.

**Current state:** No existing codebase is modified. Two Emacs Lisp files (`tools-rss.el`, `org-roam-url-catcher.el`) are ported as daemon modules with all interactive patterns stripped and replaced with `.env`-driven configuration.

**Constraints:**
- Orgzly syncs via WebDAV — concurrent read/write must not corrupt files
- Lock files must be disabled to prevent WebDAV sync failures
- All credentials via `.env`, never hardcoded
- LLM API calls must sanitize sensitive content before transmission
- Daemon must be cron-driven, not timer-driven
- SQLite DB is rebuilt on startup; Elfeed DB preserved unless corrupt

**Stakeholders:** Single user operating mobile Orgzly capture + VPS-hosted processing daemon.

## Goals / Non-Goals

**Goals:**
- Autonomous inbox processing every 30 minutes via LLM
- URL capture with full article fetching via trafilatura
- Daily RSS/arXiv digest generation at 9:30 AM
- Atomic inbox purge at 4:00 AM
- Durable message logging outside `/data` volume
- Structured logging to `/data/sem-log.org` readable in Orgzly
- Dead Letter Queue for malformed LLM output in `/data/errors.org`
- Git-ready org-roam directory for future GitHub sync
- Package pinning via straight.el lockfile for reproducible builds

**Non-Goals:**
- Interactive user prompts or confirmation dialogs
- Real-time processing (cron-driven, not event-driven)
- Multi-user support or authentication beyond HTTP Basic Auth
- Web UI or dashboard
- Bi-directional sync conflict resolution (accepted risk documented)
- Git remote URL configuration or SSH key provisioning (`GIT_REMOTE_URL` env var, git push/pull — deferred to `github-integration` change)
- Log rotation (operator responsibility via logrotate)

## Decisions

### 1. Docker Compose Architecture

**Decision:** Two containers (WebDAV + Emacs daemon) sharing `/data` volume, plus separate `./logs` mount for message persistence.

**Rationale:** WebDAV provides standard Orgzly sync protocol. Emacs daemon provides full Org-mode + Elisp ecosystem. Shared volume enables file-based IPC without network overhead. Separate logs mount survives `/data` volume replacement.

**Alternatives considered:**
- Single container with built-in WebDAV: Rejected — davserver is mature, tested; reinventing adds risk
- Network-based IPC (Redis, sockets): Rejected — file-based cursor tracking is simpler, durable, debuggable
- Kubernetes: Rejected — overkill for single-tenant VPS; docker-compose is sufficient

### 2. Cron-Driven Execution Model

**Decision:** All scheduled tasks via system cron + `emacsclient`, not Emacs internal timers.

**Rationale:** Cron provides external scheduling — a crashed daemon doesn't accumulate pending tasks. Each invocation is independent. Crontab is versioned and requires rebuild to change, preventing accidental schedule drift.

**Alternatives considered:**
- `run-at-time` timers: Rejected — stateful, lost on crash, harder to audit
- Emacs timer packages: Rejected — same issues; cron is OS-level, more reliable

### 3. Content-Hash Cursor for Inbox Tracking

**Decision:** `/data/.sem-cursor.el` tracks processed headline hashes, not line numbers or timestamps.

**Rationale:** Content hashing is invariant to file reordering. Supports atomic purge via file replacement. Enables retry logic (failed LLM calls don't advance cursor).

**Alternatives considered:**
- Line numbers: Rejected — fragile to edits, mobile sync may reorder
- Timestamps: Rejected — requires headline modification, breaks read-only contract
- Marker-based (tags): Rejected — loses idempotency guarantee

### 4. Atomic Purge via `rename-file`

**Decision:** Inbox purge writes to temp file, then `rename-file` to target path.

**Rationale:** POSIX `rename` is atomic — crash before completion leaves original file untouched. Guarantees no partial writes corrupt inbox.

**Alternatives considered:**
- In-place buffer save: Rejected — non-atomic, crash mid-write corrupts file
- `write-region` with delete: Rejected — two operations, crash between them loses data

### 5. Elfeed DB Preservation with Corruption Recovery

**Decision:** Elfeed DB never wiped unless `(elfeed-db-load)` raises error.

**Rationale:** Entries fetched before container restart are valuable state. Corruption is rare; recovery by wipe is acceptable. Normal restarts preserve DB.

**Alternatives considered:**
- Always rebuild: Rejected — unnecessary API re-fetches, slow startup
- Manual intervention on corruption: Rejected — daemon should self-heal

### 6. org-roam DB Always Rebuilt

**Decision:** Delete `org-roam.db` + `*.db-shm/wal` on every startup, then `(org-roam-db-sync)`.

**Rationale:** DB is deterministically derived from `.org` files. Rebuild is safe, idempotent, handles pre-placed files and daemon-generated files uniformly.

**Alternatives considered:**
- Preserve DB: Rejected — pre-placed files wouldn't be indexed without manual sync
- Incremental sync: Rejected — more complex, same end state

### 7. Security Masking via Token Replacement

**Decision:** Sensitive blocks replaced with opaque tokens before LLM, restored after.

**Rationale:** Zero sensitive content reaches LLM API. Token round-trip is simpler than parsing/filtering structured content.

**Alternatives considered:**
- Pre-filter sensitive lines: Rejected — error-prone, may miss edge cases
- LLM instruction to ignore: Rejected — unreliable, content still transmitted

### 8. URL Sanitization Scope

**Decision:** Sanitize URLs (`http` → `hxxp`) in `inbox-processing` and `rss-digest` output only. Not in `url-capture` output.

**Rationale:** `tasks.org` and `morning-read/` are human-readable; sanitized URLs prevent accidental clicks. `org-roam/` nodes need real URLs for `#+ROAM_REFS` and org-roam backlinks.

**Alternatives considered:**
- Sanitize everywhere: Rejected — breaks org-roam link resolution
- Never sanitize: Rejected — safety risk in daily digest files

### 9. Dead Letter Queue for Malformed LLM Output

**Decision:** Malformed LLM output → append to `/data/errors.org`, mark headline processed.

**Rationale:** Prevents infinite retry loops. Operator can inspect and manually recover. DLQ pattern isolates failures from main pipeline.

**Alternatives considered:**
- Retry indefinitely: Rejected — wastes API quota, blocks pipeline
- Skip silently: Rejected — loses debugging information

### 10. straight.el Package Pinning

**Decision:** `straight/versions/default.el` lockfile committed to repo. Packages installed at Docker build time, not runtime.

**Rationale:** Reproducible builds across container rebuilds. Build fails if package unavailable — no silent degradation. Runtime is faster (no package installation).

**Alternatives considered:**
- MELPA latest at runtime: Rejected — non-deterministic, breaks without notice
- Manual package list: Rejected — drifts over time, hard to reproduce

### 11. Messages Redirection to Host Mount

**Decision:** `*Messages*` flushed to `/var/log/sem/messages.log` via `post-command-hook`, mounted from host as `./logs`.

**Rationale:** Survives container restart and `/data` volume replacement. Operator can tail logs from host. Append-only prevents log rotation conflicts.

**Alternatives considered:**
- Log to `/data`: Rejected — lost if volume replaced
- Docker logs: Rejected — lost on container removal, harder to query

### 12. Git Pre-Wiring for Future Sync

**Decision:** Initialize git in `/data/org-roam/` at startup if `.git/` absent. Write `.gitignore` for DB files. SSH volume declared but empty.

**Rationale:** Enables future GitHub integration without architectural changes. Git repo exists before first note, clean history.

**Alternatives considered:**
- Manual git setup: Rejected — operator burden, easy to forget
- No git: Rejected — forecloses future sync feature

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| WebDAV concurrent write corrupts file | Lock files disabled; atomic purge via `rename-file`; Orgzly is sole writer of `inbox-mobile.org` |
| LLM API rate limit (429) | Cursor not advanced on API error — retries next cron run; no exponential backoff (simple, acceptable for low volume) |
| Malformed LLM output loses headline | DLQ captures raw output; operator recovery required; headline marked processed to prevent loop |
| Git merge conflicts (laptop + VPS edit same file) | Accepted risk; daemon only creates new files; laptop operator responsible for pulling before editing |
| trafilatura Python dependency breaks | Dockerfile declares explicitly; build fails if unavailable; error logged to `/data/errors.org` if runtime fails |
| Elfeed DB corruption loses fetched entries | Wipe and re-fetch; rare event; acceptable data loss vs. manual intervention |
| `*Messages*` log grows unbounded | Operator responsibility via `logrotate`; daemon never rotates |
| Cron job overlap (4AM purge during inbox processing) | Cron daemon serializes; no locking required; 4AM window chosen for low activity |
| Sensitive masking token collision | Opaque tokens generated with sufficient entropy; collision probability negligible for single-tenant |
| straight.el lockfile drifts from upstream | Operator must manually update lockfile; intentional trade-off for stability |
| SQLite WAL files left after crash | Startup cleanup deletes `*.db-shm`, `*.db-wal`; safe because DB rebuilt anyway |

## Migration Plan

**Not applicable** — this is a greenfield system with no existing deployment to migrate.

**Deployment steps for operator:**
1. Clone repository to VPS
2. Copy `.env.example` to `.env`, set `OPENROUTER_KEY` and `OPENROUTER_MODEL`
3. Create `./logs/` directory: `mkdir -p logs`
4. (Optional) Pre-populate `/data/org-roam/` with existing notes via git clone
5. (Optional) Copy `feeds.org` to `/data/feeds.org`
6. Run `docker-compose up -d`
7. Verify: `docker-compose logs -f emacs` shows "Daemon ready"

**Rollback strategy:**
- Stop containers: `docker-compose down`
- Data persists in `/data` volume — no data loss on stop
- Revert to previous git commit, rebuild: `docker-compose build --no-cache && docker-compose up -d`

## Open Questions (Resolved)

1. **trafilatura version pinning:** Use `requirements.txt` with `trafilatura>=2.0.0,<3.0.0`. Dockerfile uses `pip install -r requirements.txt`. `requirements.txt` is committed to the repo.

2. **Log rotation defaults:** Provide `deploy/logrotate.conf` in the repo, configured for `./logs/messages.log`. Operator copies to `/etc/logrotate.d/sem`. Versioned alongside the deployment config.

3. **straight lockfile update cadence:** Manual-only. Lockfile is updated intentionally by operator when upgrading packages. No scheduled task.

4. **Error recovery workflow:** Manual-only. Operator inspects `/data/errors.org` and manually re-triggers if needed. No companion script.



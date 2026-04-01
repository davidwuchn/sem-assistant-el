# SEM Assistant Elisp Daemon

A self-hosted Emacs daemon that autonomously processes mobile-captured Org notes and RSS feeds via LLM.

## Features

- **Inbox Processing**: Every 30 minutes, processes headlines from `inbox-mobile.org` via LLM
- **URL Capture**: Fetches full article text via trafilatura and creates org-roam nodes under `/data/org-roam/org-files/`
- **RSS Digest**: Daily morning digest from RSS feeds at 9:30 AM
- **arXiv Digest**: Daily arXiv paper digest for research tracking
- **Atomic Purge**: Daily cleanup of processed headlines at 4:00 AM
- **Structured Logging**: All operations logged to `/data/sem-log.org` (readable in Orgzly)
- **Error Handling**: Dead Letter Queue for malformed LLM output in `/data/errors.org`
- **Bounded Retry**: URL capture failures retry up to 3 times before moving to DLQ
- **GitHub Sync**: Automated sync of org-roam to GitHub every 6 hours
- **Daemon Watchdog**: Operational liveness probe every 15 minutes with startup grace and restart trigger
- **WebDAV TLS**: HTTPS-enabled WebDAV for secure Orgzly sync

## Architecture

Two Docker containers:
- **Emacs Daemon**: Runs all Elisp modules, processes inbox, generates digests
- **WebDAV Server**: Provides Orgzly sync endpoint

Shared volume: `/data` contains all Org files, databases, and logs.

## Quick Start

### Prerequisites

- Docker Engine with the Docker Compose plugin (`docker compose`) installed on VPS
- Eask installed for local development/testing (https://emacs-eask.github.io/)
- OpenRouter API key (https://openrouter.ai/keys)
- Orgzly configured on mobile device

If your host only provides legacy `docker-compose`, substitute `docker-compose` for `docker compose` in commands below.

### Deployment

1. **Clone the repository** to your VPS:

   _Illustrative example (replace placeholder values):_
   ```bash
   git clone <repository-url> sem-assistant-el
   cd sem-assistant-el
   ```

2. **Create `.env` configuration**:
   ```bash
   cp .env.example .env
   ```
   Edit `.env` and set:
   - `OPENROUTER_KEY=your-api-key-here`
   - `OPENROUTER_MODEL=your-preferred-model` (e.g., `anthropic/claude-sonnet-4-5`)
   - `CLIENT_TIMEZONE=Europe/Belgrade` (required IANA timezone used for runtime scheduling semantics)
   - Optional: `OPENROUTER_WEAK_MODEL=your-lower-cost-model` for Pass 1 `:task:` normalization
   - `WEBDAV_PASSWORD=ChangeMeStrongPassword2026` (replace with your own strong value)

   If `OPENROUTER_WEAK_MODEL` is unset or empty, weak-tier requests automatically
   fall back to `OPENROUTER_MODEL`.

3. **Create logs directory**:
   ```bash
   mkdir -p logs
   ```

4. **(Optional) Pre-populate data**:
   - Clone existing org-roam notes to `./data/org-roam/org-files/`
   - Copy `feeds.org` to `./data/feeds.org` for Elfeed subscriptions

### Path Contract (Notes Root vs Repository Root)

- **Notes root**: `/data/org-roam/org-files/` (all org-roam node creation and indexing)
- **Repository root**: `/data/org-roam/` (git init/readiness/sync lifecycle)
- New URL-capture notes are written only under `org-files/`; top-level `/data/org-roam/` is not used as a note destination.

5. **Create prompt files** (required for RSS digest generation):
   ```bash
   mkdir -p ./data/prompts
   ```
   Create `./data/prompts/general-prompt.txt` with your RSS digest template. Available placeholders:
   - `%s` (1st) - Number of days
   - `%s` (2nd) - Category list
   - `%s` (3rd) - Number of days (repeated for summary section)
   - `%s` (4th) - Entries text

   Create `./data/prompts/arxiv-prompt.txt` with your arXiv digest template. Available placeholders:
   - `%s` (1st) - Category list
   - `%s` (2nd) - Number of days
   - `%s` (3rd) - Entries text

   Template content is user-defined; this repository does not ship prompt defaults.

6. **Start the daemon**:
   ```bash
   docker compose up -d
   ```

7. **Verify startup**:
   ```bash
   docker compose logs -f emacs
   ```
   Look for: `SEM: Daemon ready`

   **Note:** If startup fails with "Required prompt file missing", ensure step 5 is completed.

### Common Startup Failures (and what to do)

- **`OPENROUTER_KEY` missing/empty**: LLM requests fail; set it in `.env` from `.env.example` and restart.
- **`OPENROUTER_MODEL` missing/empty**: request routing fails; set a valid model ID in `.env` and restart.
- **`CLIENT_TIMEZONE` missing/invalid**: startup fails fast before cron and inbox processing; set a valid IANA zone (for example `Europe/Belgrade`) and restart.
- **`docker compose` not found**: install Docker Compose plugin, or use legacy `docker-compose` binary if already installed.
- **WebDAV cert files unavailable**: production `webdav` start can fail before certificates exist; complete certbot issuance first.
- **Port 80 in use during certbot flow**: stop conflicting services before running `certbot` profile.

## Dummy VPS Deployment (Non-Production Walkthrough)

**WARNING: This section is a learning-only dummy flow. Do not use these placeholder values in production.**

1. **Prepare a fresh VPS with Podman tooling**:
   ```bash
   sudo apt update
   sudo apt install -y podman podman-compose git
   ```

2. **Clone and enter the repository**:

   _Illustrative example (replace placeholder repository URL):_
   ```bash
   git clone https://example.invalid/your-user/sem-assistant-el.git
   cd sem-assistant-el
   ```

3. **Create dummy environment configuration**:

   _Placeholder-only example (never use real keys/domains from this README):_
   ```bash
   cp .env.example .env
   sed -i 's/^OPENROUTER_KEY=.*/OPENROUTER_KEY=placeholder-openrouter-key/' .env
   sed -i 's/^OPENROUTER_MODEL=.*/OPENROUTER_MODEL=openai\/gpt-4o-mini/' .env
   sed -i 's/^WEBDAV_DOMAIN=.*/WEBDAV_DOMAIN=example.invalid/' .env
   sed -i 's/^CERTBOT_EMAIL=.*/CERTBOT_EMAIL=admin@example.invalid/' .env
   sed -i 's/^WEBDAV_PASSWORD=.*/WEBDAV_PASSWORD=PlaceholderPass1234567890/' .env
   ```

4. **Review where repository configuration lives**:
   - Runtime environment values: `.env` (template: `.env.example`)
   - Container wiring and cert mounts: `docker-compose.yml`
   - Apache WebDAV startup/config templates: `webdav/apache/`
   - Legacy WebDAV config reference: `webdav-config.yml` (not used by current `webdav` service)

5. **Issue dummy certificates with certbot flow**:
   ```bash
   podman-compose --profile certbot up -d certbot
   podman-compose logs -f certbot
   ```
   For first validation keep `CERTBOT_STAGING=true` in `.env`.

6. **Start services with Podman Compose**:
   ```bash
   podman-compose up -d
   podman-compose logs -f emacs
   ```

7. **Renewal lifecycle check (certbot container loop)**:
   ```bash
   podman-compose logs certbot
   ```
   Confirm renewal checks continue on `CERTBOT_RENEW_INTERVAL`.

**WARNING: This is not a production hardening guide. Add your own provider-specific firewall, backup, secret-management, and monitoring controls separately.**

### Orgzly Configuration

Configure Orgzly to sync via WebDAV:
- **URL**: `https://<your-domain.com>/`
- **Username**: `orgzly` (or custom from `.env`)
- **Password**: `<your-password>` (from `.env`)

Files to sync:
- `inbox-mobile.org` - Mobile capture inbox
- `tasks.org` - Processed tasks (auto-created)
- `sem-log.org` - Structured logs (optional, readable in Orgzly)
- `errors.org` - Error Dead Letter Queue (optional)

## Task Syntax

The SEM Assistant processes headlines from `inbox-mobile.org` based on tags:

### `:task:` - Task Generation

Headlines tagged with `:task:` are sent to the LLM for structured task generation:

```org
* Buy groceries :task:
* Review PR for project X :task:work:
* Call dentist tomorrow :task:routine:
```

**Allowed Tags:**
- `work` - Work-related tasks
- `family` - Family/personal tasks  
- `routine` - Routine/maintenance tasks (default if no tag specified)
- `opensource` - Open source project tasks

The LLM generates a structured Org TODO entry with:
- Cleaned, actionable title
- Auto-generated UUID in `:ID:` property
- `:FILETAGS:` set to one of the allowed tags
- Optional deadline/scheduled dates (if specified in original)

### `:link:` - URL Capture

Headlines tagged with `:link:` trigger article capture:

```org
* https://example.com/article :link:
* Interesting article title :link:
```

The system fetches the article content via trafilatura and creates an org-roam node with AI-generated summary.

### URL Headlines (Auto-detected)

Headlines that start with `http://` or `https://` are automatically treated as link headlines:

```org
* https://github.com/user/repo
```

## Scheduled Tasks

| Time | Task | Description |
|------|------|-------------|
| Every 30 min | Inbox Processing | Process unprocessed headlines from `inbox-mobile.org` |
| 4:00 AM | Inbox Purge | Remove processed headlines (atomic) |
| 5:00-8:00 AM | Elfeed Update | Refresh RSS feed database (hourly) |
| 9:30 AM | RSS Digest | Generate daily digest from last 24 hours |
| Every 15 min | Daemon Watchdog | Probe daemon responsiveness and trigger container restart on failure |
| Every 6 hours | GitHub Sync | Sync `/data/org-roam` to remote repository |

All schedule times in this table are interpreted in `CLIENT_TIMEZONE`.

### WARNING: Orgzly Sync Timing

When concurrent edits happen, the planner and WebDAV endpoint reject stale writes instead of silently overwriting newer content.

| Window | Time | Reason |
|--------|------|--------|
| Processing | `XX:28–XX:32` and `XX:58–XX:02` (every hour) | Planner may detect version conflicts and retry; repeated conflicts can end in explicit non-success |
| Purge | `04:00–04:05` (daily) | Purge rewrites `inbox-mobile.org`; clients should pull latest state before pushing |

**Why this matters:** Atomic replacement prevents partial files, but conflicts still require pull-before-push recovery by clients.

**Recommendation:** Configure Orgzly to sync at safe times like `XX:15` or `XX:45` (midway between cron triggers), or sync manually when needed.

### Daemon Watchdog Scope

- The watchdog cron job (`/usr/local/bin/sem-daemon-watchdog`) is operational-only.
- It only probes daemon liveness using `emacsclient -s sem-server` and handles restart supervision.
- It does not run inbox processing, purge, RSS generation, or git sync workflows.

### Watchdog Troubleshooting

- Check container logs for `SEM_WATCHDOG` events (`PROBE_OK`, `PROBE_FAIL`, `RESTART_SUPPRESSED_GRACE`, `LOCK_CONTENTION_SKIP`, `RESTART_TRIGGERED`, `RESTART_ALREADY_SATISFIED`).
- Tune probe timeout with `SEM_WATCHDOG_PROBE_TIMEOUT_SEC` (default `45`).
- Tune startup grace with `SEM_WATCHDOG_STARTUP_GRACE_SEC` (default `180`).
- If you see repeated restarts, inspect Emacs startup and external dependencies first, then raise grace or timeout as needed.

## File Structure

```
sem-assistant-el/
├── Eask                    # Eask dependency manifest
├── app/elisp/              # Elisp modules
│   ├── init.el             # Daemon initialization
│   ├── sem-core.el         # Core logging and utilities
│   ├── sem-security.el     # Security masking and URL sanitization
│   ├── sem-llm.el          # LLM integration wrapper
│   ├── sem-router.el       # Inbox routing logic
│   ├── sem-url-capture.el  # URL to org-roam pipeline
│   └── sem-rss.el          # RSS digest generation
├── data/                   # Shared volume (persisted)
│   ├── org-roam/           # Git repository root for org-roam sync
│   │   └── org-files/      # Canonical org-roam notes subtree
│   ├── elfeed/             # Elfeed database
│   ├── morning-read/       # Daily digests
│   ├── inbox-mobile.org    # Mobile inbox (Orgzly writes)
│   ├── tasks.org           # Processed tasks
│   ├── sem-log.org         # Structured logs
│   └── errors.org          # Error DLQ
├── logs/                   # *Messages* persistence
├── docker-compose.yml      # Container orchestration
├── Dockerfile.emacs        # Emacs container build
├── webdav/                 # Apache WebDAV startup/config templates
├── crontab                 # Scheduled tasks
└── .env                    # Configuration (gitignored)
```

## Log Rotation

Configure logrotate on the host for daily message logs in `./logs/messages-*.log`:

```bash
sudo tee /etc/logrotate.d/sem-assistant >/dev/null <<'EOF'
/absolute/path/to/sem-assistant-el/logs/messages-*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF
```

Example logrotate config (adjust the absolute path):
```
/var/home/sem/github/sem-assistant-el/logs/messages-*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
```

## Error Recovery

When errors occur, they are logged to `/data/errors.org` with:
- Original input that caused the failure
- Raw LLM output (if applicable)
- Error message

To recover:
1. Inspect `/data/errors.org` in Orgzly or Emacs
2. Manually re-process if needed
3. Errors are never automatically retried (to prevent infinite loops)

## Rollback Strategy

To rollback to a previous version:

1. **Stop containers**:
   ```bash
   docker-compose down
   ```

2. **Revert to previous git commit**:
   ```bash
   git revert HEAD
   ```

3. **Rebuild and restart**:
   ```bash
   docker-compose build --no-cache
   docker-compose up -d
   ```

Data in `/data` volume persists across restarts.

## GitHub Sync Configuration

The SEM Assistant can automatically sync your org-roam notes to a GitHub repository.

### Setup

1. **Create a GitHub repository** for your org-roam notes (e.g., `my-org-roam`)

2. **Initialize the org-roam directory as a git repository**:
   ```bash
   cd ./data/org-roam
   git init
   git remote add origin git@github.com:yourusername/my-org-roam.git
   git add .
   git commit -m "Initial commit"
   git push -u origin main
   ```

3. **Generate an SSH key** for the container:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/vps-org-roam/id_rsa -C "sem-assistant"
   ```

4. **Add the public key to GitHub**:
   - Copy `~/.ssh/vps-org-roam/id_rsa.pub`
   - Add it as a Deploy Key in your GitHub repository settings

5. **Verify the volume mount** in `docker-compose.yml`:
   ```yaml
   volumes:
     - ~/.ssh/vps-org-roam:/root/.ssh:ro
   ```

### How It Works

- Sync runs every 6 hours (00:00, 06:00, 12:00, 18:00 in `CLIENT_TIMEZONE`)
- Git sync runs from `/data/org-roam` repository root and includes `org-files/` note changes
- Commits all changes with timestamp: `Sync org-roam: YYYY-MM-DD HH:MM:SS`
- Skips if no changes detected
- Uses SSH key for authentication (no passwords stored)

### Manual Sync

To trigger a sync manually:
```bash
docker exec sem-emacs emacsclient -e "(sem-git-sync-org-roam)"
```

## WebDAV TLS Setup

The WebDAV service uses HTTPS on port 443 and reads certificates from host-mounted
Let's Encrypt paths.

### Prerequisites

1. **DNS and networking for HTTP-01**:
   - `WEBDAV_DOMAIN` must resolve publicly to this host.
   - Inbound TCP port `80` must be reachable for ACME challenge validation.

2. **Set required environment values** in `.env`:
   ```bash
   WEBDAV_DOMAIN=your-domain.com
   CERTBOT_EMAIL=you@example.com
   CERTBOT_STAGING=true
   WEBDAV_PASSWORD=UseAtLeast20CharsWithUpperLower123
   ```

   Production WebDAV startup enforces password policy: at least 20 characters,
   with at least one lowercase letter, one uppercase letter, and one digit.

### Configuration

The production WebDAV service uses Apache `httpd` + `mod_dav` and keeps the same Let's Encrypt live-path contract:

`/certs/live/<WEBDAV_DOMAIN>/fullchain.pem` and `/certs/live/<WEBDAV_DOMAIN>/privkey.pem`

### Certificate Issuance and Renewal (Certbot)

1. **Validate issuance safely against staging CA first**:
   ```bash
   docker compose --profile certbot up -d certbot
   docker compose logs -f certbot
   ```

2. **Switch to production CA** after staging succeeds:
   ```bash
   sed -i 's/^CERTBOT_STAGING=true/CERTBOT_STAGING=false/' .env
   docker compose --profile certbot up -d certbot
   docker compose logs -f certbot
   ```

3. **Start or restart WebDAV after certificates are present/renewed**:
   ```bash
   docker compose up -d webdav
   ```

   If startup fails, confirm cert readability from host before retrying:
   ```bash
   sudo test -r /etc/letsencrypt/live/$WEBDAV_DOMAIN/fullchain.pem
   sudo test -r /etc/letsencrypt/live/$WEBDAV_DOMAIN/privkey.pem
   ```

4. **Check certificate expiry visibility**:
   ```bash
   sudo openssl x509 -in /etc/letsencrypt/live/$WEBDAV_DOMAIN/fullchain.pem -noout -dates
   ```

Certbot renewal runs continuously in the `certbot` service and keeps the same
live-path contract used by WebDAV.

### Troubleshooting

- **Port 80 conflict**: stop other services binding `:80` before starting `certbot`.
- **DNS issues**: confirm `WEBDAV_DOMAIN` A/AAAA records point to this host.
- **Permission issues**: ensure `/etc/letsencrypt` files are readable in the
  `webdav` container and SELinux labels allow mounted access.
- **Issuance/renew failures**: inspect `docker compose logs certbot` for ACME error details.

### Apache WebDAV Migration and Rollback Notes

- Migration checks:
  1. `docker compose config` renders `webdav` with image `httpd:2.4` and cert mount `/etc/letsencrypt:/certs:ro,z`.
  2. `docker compose up -d webdav` succeeds only when `WEBDAV_DOMAIN`, `WEBDAV_USERNAME`, `WEBDAV_PASSWORD`, and cert files exist.
  3. Conflicting stale writes are rejected (HTTP precondition failure) and clients must pull before a successful retry.
- Rollback steps:
  1. Restore previous `webdav` service definition and legacy `webdav-config.yml` runtime wiring.
  2. `docker compose up -d webdav` to redeploy.
  3. Monitor sync behavior and logs before re-attempting migration.

### Orgzly HTTPS Configuration

Configure Orgzly to sync via HTTPS:
- **URL**: `https://<your-domain.com>/`
- **Username**: `orgzly` (or custom from `.env`)
- **Password**: `<your-password>` (from `.env`)

## Security Notes

- **Credentials**: All secrets via `.env`, never hardcoded
- **Lock files**: Disabled to prevent WebDAV sync issues
- **Local variables**: Disabled to prevent malicious Org payloads
- **URL contract**: `tasks.org` and `morning-read/` outputs are defanged (`http` -> `hxxp`), while url-capture org-roam artifacts keep canonical `http://`/`https://` in both `#+ROAM_REFS` and `Source: [[...][...]]`
- **Sensitive blocks**: Content between `#+begin_sensitive` / `#+end_sensitive` never sent to LLM; restored as plain text (no markers) after LLM processing
- **TLS**: WebDAV uses HTTPS with host-mounted certificates

**Environment Variable:**
- `SEM_PROMPTS_DIR` - Override prompt files location (default: `/data/prompts/`)
- `SEM_WATCHDOG_PROBE_TIMEOUT_SEC` - Watchdog probe timeout in seconds (default: `45`)
- `SEM_WATCHDOG_STARTUP_GRACE_SEC` - Startup grace period in seconds (default: `180`)
- `OPENROUTER_WEAK_MODEL` - Optional weak-tier model for Pass 1 `:task:` normalization; unset/empty falls back to `OPENROUTER_MODEL`
- `SEM_TASK_API_MAX_RETRIES` - Optional cap for task LLM API-failure retries (default: `3`)
- `CLIENT_TIMEZONE` - Required IANA timezone controlling cron timing, Pass 1/Pass 2 runtime datetime context, purge 4:00 AM window, RSS digest date labels, and sem-log/day-log rollover boundaries

### Model Tier Rollout / Rollback

- **Rollout**
  1. Deploy with only `OPENROUTER_MODEL` first (all flows use medium/default behavior).
  2. Set `OPENROUTER_WEAK_MODEL` and restart containers to enable weak tier for Pass 1 task normalization.
  3. Verify startup/request logs show expected tier-to-model mapping.
- **Rollback**
  1. Unset `OPENROUTER_WEAK_MODEL` (or set it empty) and restart.
  2. Weak-tier traffic immediately falls back to `OPENROUTER_MODEL` without code changes.

## Unit Tests

Run all unit tests (default path):

```bash
eask test ert app/elisp/tests/sem-test-runner.el
```

Run a single test file:

```bash
eask emacs --batch \
  --load app/elisp/tests/sem-mock.el \
  --load app/elisp/tests/sem-core-test.el \
  --eval "(ert-run-tests-batch-and-exit)"
```

Run a single named test:

```bash
eask emacs --batch \
  --load app/elisp/tests/sem-mock.el \
  --load app/elisp/tests/sem-core-test.el \
  --eval "(ert-run-tests-batch-and-exit 'sem-core-test-cursor-roundtrip)"
```

## Integration Tests

The integration test suite provides end-to-end verification of the full inbox processing pipeline.

The runner supports two explicit modes:
- `paid-inbox` (default): full inbox + LLM assertions with real API calls.
- `local-git-sync`: deterministic no-cost git-sync validation against a local bare remote.

### Prerequisites

- **podman** and **podman-compose** installed (not Docker)
- `OPENROUTER_KEY` environment variable set
- WebDAV credentials configured in `.env`

### Running Tests

**WARNING: Real LLM API calls are made. This incurs cost (~3 API calls per run).**

**DO NOT RUN this script unless you intend to make real API calls.** The test suite is designed to be run manually by human operators only — it is never run automatically.

From the repository root:

```bash
bash dev/integration/run-integration-tests.sh
```

### Running No-Cost Local Git-Sync Validation

Use this path for routine git-sync readiness checks without OpenRouter, GitHub, or SSH credentials:

```bash
SEM_INTEGRATION_MODE=local-git-sync bash dev/integration/run-integration-tests.sh
```

This local path validates:
- changed-content sync creates exactly one new local commit
- successful push propagation to local bare remote (`file://...`)
- clean-repo no-op success with unchanged local/remote tips
- failure classification for invalid local repository and unavailable push target

Local git-sync artifacts are deterministic and written to:

```
test-results/
└── local-git-sync-run/
    ├── local-git-sync-results.txt
    ├── local-git-sync-changed.stdout
    ├── local-git-sync-noop.stdout
    ├── local-git-sync-invalid-repo.stdout
    └── local-git-sync-unavailable-remote.stdout
```

Failure signals for operators:
- `LOCAL_GIT_SYNC_RESULT:FAIL` in `local-git-sync-results.txt`
- `FAILURE_CLASS:LOCAL_REPO_INVALID:FAIL`
- `FAILURE_CLASS:PUSH_TARGET_UNAVAILABLE:FAIL`
- script exit code `1`

For Apache WebDAV runtime checks (no LLM calls), run the separate smoke test:

```bash
bash dev/integration/run-webdav-httpd-smoke-test.sh
```

This validates:
- host `/data` mount semantics in both directions (host->WebDAV and WebDAV->host)
- conditional write behavior for Apache/mod_dav (`PUT` rejected on stale/missing preconditions, accepted on fresh precondition)

The script will:
1. Start containers with test configuration (port 16065)
2. Upload a test inbox with 3 headlines via WebDAV
3. Trigger inbox processing via emacsclient
4. Poll for task completion (max 120 seconds)
5. Collect all artifacts (tasks.org, logs, container logs)
6. Run assertions (TODO count, keyword presence, Org validity)
7. Tear down containers unconditionally

### Test Results

Results are saved to timestamped directories:

```
test-results/
└── YYYY-MM-DD-HH-MM-SS-run/
    ├── inbox-sent.org        # Copy of test inbox
    ├── tasks.org             # Processed output
    ├── sem-log.org           # Structured logs
    ├── errors.org            # Error DLQ (may be empty)
    ├── messages-*.log        # Message logs
    ├── emacs-container.log   # Emacs container logs
    ├── webdav-container.log  # WebDAV container logs
    └── validation.txt        # Assertion results
```

### Exit Codes

- **0**: All assertions passed
- **1**: One or more assertions failed, or timeout occurred

### Post-Mortem Analysis

If tests fail, inspect the run directory:
- Check `validation.txt` for which assertions failed
- Review `emacs-container.log` for daemon errors
- Compare `inbox-sent.org` vs `tasks.org` to see LLM output
- Check `messages-*.log` for runtime diagnostics

### Cleanup

Containers are stopped automatically via EXIT trap. Test data persists in `test-data/` for inspection. To clean up manually:

```bash
rm -rf test-data/ test-results/
```

## License

GPL-3.0-or-later

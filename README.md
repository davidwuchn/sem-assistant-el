# SEM Assistant Elisp Daemon

A self-hosted Emacs daemon that autonomously processes mobile-captured Org notes and RSS feeds via LLM.

## Features

- **Inbox Processing**: Every 30 minutes, processes headlines from `inbox-mobile.org` via LLM
- **URL Capture**: Fetches full article text via trafilatura and creates org-roam nodes
- **RSS Digest**: Daily morning digest from RSS feeds at 9:30 AM
- **arXiv Digest**: Daily arXiv paper digest for research tracking
- **Atomic Purge**: Daily cleanup of processed headlines at 4:00 AM
- **Structured Logging**: All operations logged to `/data/sem-log.org` (readable in Orgzly)
- **Error Handling**: Dead Letter Queue for malformed LLM output in `/data/errors.org`
- **Bounded Retry**: Failed LLM requests retry up to 3 times before moving to DLQ
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

- Docker and Docker Compose installed on VPS
- Eask installed for local development/testing (https://emacs-eask.github.io/)
- OpenRouter API key (https://openrouter.ai/keys)
- Orgzly configured on mobile device

### Deployment

1. **Clone the repository** to your VPS:
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

3. **Create logs directory**:
   ```bash
   mkdir -p logs
   ```

4. **(Optional) Pre-populate data**:
   - Clone existing org-roam notes to `./data/org-roam/`
   - Copy `feeds.org` to `./data/feeds.org` for Elfeed subscriptions

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

   Example templates are in `data/prompts/` after first run, or copy from the repository examples.

6. **Start the daemon**:
   ```bash
   docker-compose up -d
   ```

6. **Verify startup**:
   ```bash
   docker-compose logs -f emacs
   ```
   Look for: `SEM: Daemon ready`

   **Note:** If startup fails with "Required prompt file missing", ensure step 5 is completed.

### Orgzly Configuration

Configure Orgzly to sync via WebDAV:
- **URL**: `http://<your-vps-ip>/`
- **Username**: `orgzly` (or custom from `.env`)
- **Password**: `<your-password>` (from `.env`)

Files to sync:
- `inbox-mobile.org` - Mobile capture inbox
- `tasks.org` - Processed tasks (auto-created)
- `sem-log.org` - Structured logs (optional, readable in Orgzly)
- `errors.org` - Error Dead Letter Queue (optional)

## Task Syntax

The SEM Assistant processes headlines from `inbox-mobile.org` based on tags:

### `@task` - Task Generation

Headlines tagged with `@task` are sent to the LLM for structured task generation:

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

### `@link` - URL Capture

Headlines tagged with `@link` trigger article capture:

```org
* https://example.com/article :@link:
* Interesting article title :@link:
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

### Daemon Watchdog Scope

- The watchdog cron job (`/usr/local/bin/sem-daemon-watchdog`) is operational-only.
- It only probes daemon liveness using `emacsclient -s sem-server` and handles restart supervision.
- It does not run inbox processing, purge, RSS generation, or git sync workflows.

### Watchdog Troubleshooting

- Check container logs for `SEM_WATCHDOG` events (`PROBE_OK`, `PROBE_FAIL`, `RESTART_SUPPRESSED_GRACE`, `LOCK_CONTENTION_SKIP`, `RESTART_TRIGGERED`, `RESTART_ALREADY_SATISFIED`).
- Tune probe timeout with `SEM_WATCHDOG_PROBE_TIMEOUT_SEC` (default `45`).
- Tune startup grace with `SEM_WATCHDOG_STARTUP_GRACE_SEC` (default `180`).
- If you see repeated restarts, inspect Emacs startup and external dependencies first, then raise grace or timeout as needed.

### ⚠️ WARNING: Orgzly Sync Timing

**Orgzly must NOT sync (push or pull) during the following windows to prevent silent data loss:**

| Window | Time | Reason |
|--------|------|--------|
| Processing | `XX:28–XX:32` and `XX:58–XX:02` (every hour) | Inbox processing performs non-atomic read-modify-write on `tasks.org` |
| Purge | `04:00–04:05` (daily) | Inbox purge performs non-atomic file replacement on `inbox-mobile.org` |

**Why this matters:** The server performs non-atomic read-modify-write operations on `tasks.org` and non-atomic file replacement on `inbox-mobile.org` during these windows. If Orgzly syncs concurrently, the server's write may overwrite Orgzly's changes (or vice versa) with **no error logged** and **no warning shown**.

**Recommendation:** Configure Orgzly to sync at safe times like `XX:15` or `XX:45` (midway between cron triggers), or sync manually when needed.

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
│   ├── org-roam/           # Org-roam notes
│   ├── elfeed/             # Elfeed database
│   ├── morning-read/       # Daily digests
│   ├── inbox-mobile.org    # Mobile inbox (Orgzly writes)
│   ├── tasks.org           # Processed tasks
│   ├── sem-log.org         # Structured logs
│   └── errors.org          # Error DLQ
├── logs/                   # *Messages* persistence
├── docker-compose.yml      # Container orchestration
├── Dockerfile.emacs        # Emacs container build
├── Dockerfile.webdav       # WebDAV container build
├── crontab                 # Scheduled tasks
└── .env                    # Configuration (gitignored)
```

## Log Rotation

Configure logrotate on the host for `./logs/messages.log`:

```bash
sudo cp deploy/logrotate.conf /etc/logrotate.d/sem
```

Example logrotate config:
```
/var/home/sem/github/sem-assistant-el/logs/messages.log {
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

- Sync runs every 6 hours (00:00, 06:00, 12:00, 18:00 UTC)
- Only `/data/org-roam` is synced (not the entire `/data` volume)
- Commits all changes with timestamp: `Sync org-roam: YYYY-MM-DD HH:MM:SS`
- Skips if no changes detected
- Uses SSH key for authentication (no passwords stored)

### Manual Sync

To trigger a sync manually:
```bash
docker exec sem-emacs emacsclient -e "(sem-git-sync-org-roam)"
```

## WebDAV TLS Setup

The WebDAV service uses HTTPS on port 443. TLS certificates must be provided by the host:

### Prerequisites

1. **TLS Certificates**: Obtain certificates (e.g., via Let's Encrypt):
   ```bash
   sudo certbot certonly --standalone -d your-domain.com
   ```

2. **Certificate Paths**: The docker-compose.yml expects certificates at:
   - Certificate: `/etc/letsencrypt/live/your-domain.com/fullchain.pem`
   - Private key: `/etc/letsencrypt/live/your-domain.com/privkey.pem`

### Configuration

The `webdav-config.yml` is pre-configured to use certificates from `/certs/` inside the container:

```yaml
server:
  tls: true
  cert: /certs/fullchain.pem
  key: /certs/privkey.pem
```

### Orgzly HTTPS Configuration

Configure Orgzly to sync via HTTPS:
- **URL**: `https://<your-domain.com>/`
- **Username**: `orgzly` (or custom from `.env`)
- **Password**: `<your-password>` (from `.env`)

## Security Notes

- **Credentials**: All secrets via `.env`, never hardcoded
- **Lock files**: Disabled to prevent WebDAV sync issues
- **Local variables**: Disabled to prevent malicious Org payloads
- **URL sanitization**: Applied to `tasks.org` and `morning-read/` (http → hxxp)
- **Sensitive blocks**: Content between `#+begin_sensitive` / `#+end_sensitive` never sent to LLM; restored as plain text (no markers) after LLM processing
- **TLS**: WebDAV uses HTTPS with host-mounted certificates

**Environment Variable:**
- `SEM_PROMPTS_DIR` - Override prompt files location (default: `/data/prompts/`)
- `SEM_WATCHDOG_PROBE_TIMEOUT_SEC` - Watchdog probe timeout in seconds (default: `45`)
- `SEM_WATCHDOG_STARTUP_GRACE_SEC` - Startup grace period in seconds (default: `180`)

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
└── YYYY-MM-DD:HH:MM:SS-run/
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

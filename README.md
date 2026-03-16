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

## Architecture

Two Docker containers:
- **Emacs Daemon**: Runs all Elisp modules, processes inbox, generates digests
- **WebDAV Server**: Provides Orgzly sync endpoint

Shared volume: `/data` contains all Org files, databases, and logs.

## Quick Start

### Prerequisites

- Docker and Docker Compose installed on VPS
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

5. **Start the daemon**:
   ```bash
   docker-compose up -d
   ```

6. **Verify startup**:
   ```bash
   docker-compose logs -f emacs
   ```
   Look for: `SEM: Daemon ready`

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

## Scheduled Tasks

| Time | Task | Description |
|------|------|-------------|
| Every 30 min | Inbox Processing | Process unprocessed headlines from `inbox-mobile.org` |
| 4:00 AM | Inbox Purge | Remove processed headlines (atomic) |
| 5:00-8:00 AM | Elfeed Update | Refresh RSS feed database (hourly) |
| 9:30 AM | RSS Digest | Generate daily digest from last 24 hours |

## File Structure

```
sem-assistant-el/
├── app/elisp/              # Elisp modules
│   ├── init.el             # Daemon initialization
│   ├── bootstrap-packages.el  # Package bootstrapping
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

## Security Notes

- **Credentials**: All secrets via `.env`, never hardcoded
- **Lock files**: Disabled to prevent WebDAV sync issues
- **Local variables**: Disabled to prevent malicious Org payloads
- **URL sanitization**: Applied to `tasks.org` and `morning-read/` (http → hxxp)
- **Sensitive blocks**: Content between `#+begin_sensitive` / `#+end_sensitive` never sent to LLM

## License

GPL-3.0-or-later

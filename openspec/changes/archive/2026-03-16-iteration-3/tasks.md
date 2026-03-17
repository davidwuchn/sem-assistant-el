## 1. WebDAV TLS Migration

- [x] 1.1 Create `webdav-config.yml` with TLS enabled and environment variable substitution for credentials
- [x] 1.2 Update `docker-compose.yml` to use `hacdias/webdav` image and mount config/certificates
- [x] 1.3 Update `.env.example` with `WEBDAV_USERNAME` and `WEBDAV_PASSWORD` variables
- [x] 1.4 Test WebDAV container starts with HTTPS on port 443

## 2. GitHub Sync for org-roam

- [x] 2.1 Create `sem-git-sync.el` with `sem-git-sync-org-roam` function
- [x] 2.2 Implement commit logic that respects `.gitignore` and skips when no changes
- [x] 2.3 Add SSH key configuration for git push operations
- [x] 2.4 Add cron entry for periodic sync in `crontab`
- [x] 2.5 Test sync with actual GitHub repository

## 3. Async LLM Execution

- [x] 3.1 Refactor `sem-router--route-to-task-llm` in `sem-router.el` to use async callbacks
- [x] 3.2 Refactor `sem-url-capture-process` in `sem-url-capture.el` to use async callbacks
- [x] 3.3 Refactor `sem-rss--generate-file` in `sem-rss.el` to use async callbacks
- [x] 3.4 Update `sem-llm.el` to support pure async request pattern
- [x] 3.5 Add tests verifying async behavior and callback execution

## 4. Bounded Retry Mechanism

- [x] 4.1 Create retry state management functions in `sem-core.el` or new `sem-retry.el`
- [x] 4.2 Implement `/data/.sem-retries.el` file format for tracking retry counts
- [x] 4.3 Integrate retry tracking into LLM error handling path
- [x] 4.4 Implement DLQ logic: move to `errors.org` after 3 failures
- [x] 4.5 Add tests for retry counting and DLQ behavior

## 5. Documentation Updates

- [x] 5.1 Update `README.md` with `@task` syntax documentation
- [x] 5.2 Document allowed tags and Task LLM pipeline
- [x] 5.3 Remove stale TODO comments from `sem-core.el`
- [x] 5.4 Document WebDAV TLS setup requirements
- [x] 5.5 Document GitHub sync configuration

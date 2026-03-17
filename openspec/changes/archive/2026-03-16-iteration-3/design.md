## Context

The SEM Assistant daemon currently uses a synchronous spin-wait loop `(while (not done) (sit-for 0.1))` to block and wait for LLM API responses in `sem-router.el`, `sem-url-capture.el`, and `sem-rss.el`. This blocks the Emacs daemon, which is problematic since the daemon should remain responsive. Additionally, the retry mechanism for failed LLM requests currently retries infinitely on every 30-minute cron run, without tracking the number of failed attempts.
On the infrastructure side, the current `bytemark/webdav` image is unmaintained and lacks built-in TLS support. The `org-roam` database is critical but currently not synchronized automatically to any remote location.

## Goals / Non-Goals

**Goals:**
- Replace the unmaintained WebDAV image with `hacdias/webdav` and enable TLS via host-mounted certificates.
- Implement an automated cron job to sync the `/data/org-roam` directory to a remote GitHub repository.
- Refactor the LLM request wrappers and their consumers to use fully asynchronous callbacks without blocking the Emacs daemon.
- Implement a bounded retry mechanism for LLM API errors, moving items to the DLQ after 3 failures.

**Non-Goals:**
- Generating TLS certificates automatically (they must be provided by the host).
- Migrating the existing `inbox-mobile.org` or `elfeed` data to GitHub.
- Event-based GitHub syncing (it will strictly be cron-based).

## Decisions

**1. Asynchronous LLM Requests**
- **Decision:** Remove the `sit-for` loops in `sem-router.el`, `sem-url-capture.el`, and `sem-rss.el`. The entry points will trigger the LLM request and return immediately. The callbacks will handle updating the state, writing files, and marking cursors when the response arrives.
- **Rationale:** `gptel-request` is already asynchronous. The `sit-for` loop was an artificial blocking mechanism. Removing it allows the Emacs daemon to handle other client requests or background tasks concurrently.
- **Trade-off:** The initial cron entry point (e.g., `sem-core-process-inbox`) will return before the work is actually complete. Logging will reflect the start of the process, but the outcome will be logged later by the callbacks.

**2. Bounded Retry Mechanism**
- **Decision:** Introduce `/data/.sem-retries.el` to store a mapping of `(hash . retry-count)`. When an API error occurs, the retry count is incremented. If it exceeds 3, the hash is marked as processed in `/data/.sem-cursor.el`, and the error is logged to `/data/errors.org` (DLQ).
- **Rationale:** Keeps the primary cursor tracking file simple while preventing infinite retry loops for persistently failing API endpoints.
- **Alternative Considered:** Storing retry counts directly in the cursor file. Rejected to minimize changes to existing working code.

**3. WebDAV Migration**
- **Decision:** Use `hacdias/webdav` image. Mount a custom `config.yml` that configures users using `{env}WEBDAV_USERNAME` and `{env}WEBDAV_PASSWORD`. Mount TLS certificates from the host and configure `tls: true` in the YAML if certificates are present, or document how to enable it.
- **Rationale:** The `hacdias` image is actively maintained and supports extensive configuration via YAML, including TLS and environment variable substitution for credentials.

**4. GitHub Sync**
- **Decision:** Create a shell script or Emacs defun triggered by cron that commits all changes in `/data/org-roam` and pushes to `origin`.
- **Rationale:** Cron-based synchronization is simpler and more reliable than hook-based event triggers, especially given the asynchronous nature of the new LLM callbacks.

## Risks / Trade-offs

- **Risk:** Asynchronous callbacks failing silently.
  - **Mitigation:** Wrap callback logic in `condition-case` and ensure all paths (success, error, malformed output) log appropriately to the structured log file.
- **Risk:** WebDAV configuration complexity.
  - **Mitigation:** Provide a robust, default `config.yml` that mirrors the existing simple basic auth setup, ensuring seamless transition for users.

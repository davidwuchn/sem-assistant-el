## Why

To address technical debt related to synchronous LLM requests, improve failure recovery via a retry mechanism, automate backups of org-roam data to GitHub, and improve infrastructure security by migrating the WebDAV service to a maintained, TLS-enabled implementation.

## What Changes

1. Replaces the unmaintained `bytemark/webdav` image with `hacdias/webdav`, configuring it to use TLS certificates mounted from the host.
2. Introduces a separate retry state file to track failed LLM requests and prevent infinite retry loops.
3. Implements an automated synchronization mechanism to push the `org-roam` directory to a remote Git repository via cron.
4. Refactors `sem-llm.el` consumers to use asynchronous callbacks, removing synchronous spin-wait loops.

## Capabilities

### New Capabilities

- `github-sync`: The system automatically commits and pushes the `/data/org-roam` directory to a remote GitHub repository. Constraint: Triggered via cron, not event-based. Constraint: Only applies to `org-roam`, not the entire `/data` volume. Constraint: Uses SSH key mounted into the docker container.
- `webdav-tls`: The WebDAV service uses `hacdias/webdav` and serves traffic over HTTPS. Constraint: TLS certificates must be mounted from the host volume; the container does not generate them. Constraint: WebDAV configuration must be provided via a `config.yml` file mounted into the container at `/config.yml` via `docker-compose.yml` volumes. The `docker-compose.yml` must update the command/configuration path to point to this mounted file. Constraint: User credentials within `config.yml` MUST use `{env}WEBDAV_USERNAME` and `{env}WEBDAV_PASSWORD` variables to maintain parity with the existing `.env` approach.

### Modified Capabilities

- `llm-retry-mechanism`: Modifies the existing LLM retry logic to track the number of retry attempts using a separate `/data/.sem-retries.el` file. Constraint: Cursor tracking (`.sem-cursor.el`) remains unmodified to keep its schema simple. Max retries before moving to DLQ (`errors.org`) is strictly 3.
- `async-llm-execution`: Modifies `sem-router.el` (`sem-router--route-to-task-llm`), `sem-url-capture.el` (`sem-url-capture-process`), and `sem-rss.el` (`sem-rss--generate-file`) to use purely asynchronous callbacks for LLM requests. Removes all `(while (not done) (sit-for 0.1))` synchronous spin-wait loops. The daemon must not block during any API calls. Tests must be updated or added to verify that the entry points fire requests asynchronously and that callbacks execute correctly when simulated responses arrive.
- `documentation`: Updates the `README.md` to document the `@task` syntax, allowed tags, and the Task LLM pipeline. Removes stale TODO comments from `sem-core.el`.

## Impact

- Infrastructure: `docker-compose.yml` and WebDAV configuration require TLS certificates on the host to be mounted via volumes.
- Reliability: Daemon remains responsive during LLM API calls.
- Backups: Improved data safety through automated git commits for `org-roam`.

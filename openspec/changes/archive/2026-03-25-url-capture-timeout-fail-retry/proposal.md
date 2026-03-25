## Why

URL capture currently relies on subprocess/network defaults and has no explicit daemon-level guarantee that a stuck URL capture attempt will fail within a bounded time. This can delay inbox processing and weaken reliability expectations.

## What Changes

Define a hard timeout guarantee for URL-capture processing: each link capture attempt must fail no later than 5 minutes end-to-end. Define timeout outcomes as `FAIL` for the capture attempt, while the source link remains eligible for retry via existing retry flow.

## Capabilities

### New Capabilities

- `url-capture-timeout-guarantee`: Enforce a maximum 5-minute wall-clock timeout per URL-capture attempt; when timeout is reached at any layer (download, subprocess, or orchestration/thread wait), classify the attempt as `FAIL`, emit explicit timeout logging, and keep the link in retry path instead of marking it permanently processed.

### Modified Capabilities

- `url-capture-processing`: Update timeout semantics so timeout is treated distinctly from success and from non-timeout errors; timeout must be observable in logs and routing decisions.
- `router-retry-behavior`: Ensure timeout `FAIL` for link capture does not suppress future retries; retries continue under existing retry controls without introducing infinite immediate retry loops.

## Impact

This change adds an explicit reliability contract: URL capture cannot block indefinitely and will fail fast at 5 minutes. Out of scope: changing retry policy limits/backoff strategy, modifying task-LLM routing semantics, and altering integration-test cost policy or external provider SLA behavior.

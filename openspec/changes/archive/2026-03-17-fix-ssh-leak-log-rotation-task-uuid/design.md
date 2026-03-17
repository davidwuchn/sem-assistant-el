## Context

The SEM daemon currently suffers from three independent reliability issues:

1. **SSH Agent Leak**: `sem-git-sync--setup-ssh` spawns a new `ssh-agent` process on every git sync (every 6 hours) without killing the previous one. Orphaned agent processes accumulate indefinitely until the container restarts.

2. **Unbounded Log Growth**: `sem-core--flush-messages` appends the entire `*Messages*` buffer to a single `messages.log` on every `post-command-hook`. The buffer grows without bound (Emacs never truncates it automatically in daemon mode), making the file O(N²) over time and making log triage impossible.

3. **Invalid Task UUIDs**: `sem-router--route-to-task-llm` instructs the LLM to generate its own UUID for the `:ID:` field. LLMs produce non-unique, hallucinated, or malformatted UUIDs, causing downstream processing failures.

## Goals / Non-Goals

**Goals:**
- Eliminate SSH agent process leaks by properly managing agent lifecycle
- Implement daily log rotation with automatic buffer cleanup on date rollover
- Ensure task UUIDs are valid by pre-generating them in Emacs and validating LLM responses
- Maintain backward compatibility with existing function contracts where possible
- Achieve 100% test coverage for all three bug fixes

**Non-Goals:**
- Fixing straight.el lockfile placeholder SHAs
- Fixing org-roam DB rebuild on startup
- General `*Messages*` buffer size optimization (only log write behavior changes)
- Adding rate limiting for LLM requests
- Changing git commit message format or cron schedule
- Modifying the url-capture pipeline (it already handles UUIDs correctly)

## Decisions

### 1. SSH Agent Lifecycle Management

**Decision**: Use a check-reuse-kill pattern with `unwind-protect` for guaranteed cleanup.

**Rationale**: 
- Checking `SSH_AUTH_SOCK` existence before spawning prevents unnecessary agent creation
- Using `unwind-protect` ensures teardown runs even if git push fails or raises a condition
- Tracking `sem-git-sync--agent-spawned-this-cycle` as a local boolean prevents killing pre-existing agents that other processes might depend on

**Alternative Considered**: Global agent management with persistent agent across sync cycles. Rejected because it adds complexity (need to detect stale sockets) and the containerized environment benefits from clean state on each sync.

### 2. Daily Log Rotation with Buffer Erase

**Decision**: Track last flush date in a module-level variable and erase buffer on date rollover.

**Rationale**:
- Date-based file naming (`messages-YYYY-MM-DD.log`) aligns with standard logging practices
- Erasing the `*Messages*` buffer BEFORE writing ensures the new day's file starts clean
- Using a module-level variable `sem-core--last-flush-date` avoids filesystem state dependencies

**Alternative Considered**: Using Emacs' built-in `message-log-max` to truncate the buffer. Rejected because it doesn't solve the O(N²) file growth problem and loses potentially useful same-day messages.

### 3. UUID Injection and Strict Validation

**Decision**: Pre-generate UUID via `org-id-new` in Emacs, inject into prompt, and validate exact match on response.

**Rationale**:
- `org-id-new` produces RFC-compliant UUIDs that org-roam recognizes
- Injecting the UUID into the prompt template is more reliable than instructing the LLM to generate one
- Exact-string-match validation is strict but necessary for data integrity
- Passing `injected-id` through the context plist maintains the async callback pattern

**Alternative Considered**: Post-hoc UUID validation and regeneration. Rejected because it adds complexity and the LLM might have used the wrong UUID in internal references; better to reject and DLQ malformed responses.

### 4. Test Strategy

**Decision**: Extend existing test files in-place and use `sem-mock-*` infrastructure for isolation.

**Rationale**:
- Extending `sem-git-sync-test.el`, `sem-core-test.el`, and `sem-router-test.el` preserves test history
- Mock infrastructure ensures tests run without network or filesystem side-effects
- Single command verification (`emacs --batch --load app/elisp/tests/sem-test-runner.el`) provides clear definition of done

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| **RACE-001**: Buffer erase on date rollover could lose messages if they arrive between date check and write | Acceptable risk - window is microseconds; messages are informational only, not critical data |
| **PERF-001**: `file-exists-p` check on `SSH_AUTH_SOCK` adds syscall overhead | Negligible - check runs once per 6-hour sync cycle |
| **COMPAT-001**: Changing `sem-router--validate-task-response` signature breaks external callers | No external callers exist; all internal call sites updated in same change |
| **DLQ-001**: Strict UUID validation increases DLQ rate if LLM ignores instructions | Monitoring added; DLQ is correct behavior for malformed output |
| **STATE-001**: `sem-core--last-flush-date` resets on daemon restart, causing potential double-write on restart boundary | Acceptable - duplicate messages on restart are preferable to lost messages; date changes are low-frequency |

## Migration Plan

1. **Deploy**: Standard container rollout - changes are self-contained within the Emacs daemon
2. **Rollback**: Revert container to previous image - no persistent state changes
3. **Verification**: Run `emacs --batch --load app/elisp/tests/sem-test-runner.el` and confirm exit code 0

## Open Questions

None - all technical decisions resolved in proposal review.

## Why

The current sensitive content restoration wraps restored secrets in `#begin_sensitive` blocks. This causes alignment issues when LLM output is written to tasks.org. Since sensitive content will not be re-sent to LLM after restoration, markers are unnecessary and degrade readability.

## What Changes

1. **Modify `sem-security--detokenize`**: Restore sensitive content as plain text instead of re-wrapping in `#begin_sensitive` markers.
2. **Format multi-line content**: Indent each line by 2 spaces (matching original block indentation). Add leading `\n` before content and trailing `\n` after content.
3. **Clear `blocks-alist`**: After successful restoration/write, clear the alist to avoid stale data.
4. **Update unit tests**: Modify existing tests to expect plain text restoration.
5. **Update integration tests**: Add negative assertion for marker absence, add order verification, add multi-line sensitive block to test inbox.
6. **Update documentation**: Update `README.md` and architecture/design docs to reflect plain text restoration behavior.

## Capabilities

### Modified Capabilities

- `security-masking`: `sem-security--detokenize` restores sensitive content as plain text. Multi-line content is indented 2 spaces per line with leading/trailing newlines. One-line content is placed at token position verbatim.

### New Capabilities

- `sensitive-content-order-verification`: Integration test verifies that restored sensitive content appears in the same order as the original blocks.
- `multi-line-sensitive-block-test`: Integration test inbox includes a multi-line sensitive block for comprehensive coverage.

## Specs to Update

- `openspec/specs/security-masking/spec.md` - Update Requirement "Tokens restored in output before writing" to reflect plain text restoration instead of block markers.
- `openspec/specs/task-body-to-llm/spec.md` - No spec changes needed; restoration behavior change is internal to sem-security.

## Unit Tests

### Tests that MUST NOT be modified (no-regression)

These tests verify behavior that is unchanged by this change:

| Test | Reason |
|------|--------|
| `sem-security-test-sensitive-content-masked` | Tests tokenization phase only; sensitive content not present in tokenized string. |
| `sem-security-test-url-sanitization-http` | URL sanitization, unrelated to restoration. |
| `sem-security-test-url-sanitization-https` | URL sanitization, unrelated to restoration. |
| `sem-security-test-url-sanitization-multiple-urls` | URL sanitization, unrelated to restoration. |
| `sem-security-test-url-sanitization-preservation` | URL sanitization, unrelated to restoration. |
| `sem-security-test-url-sanitization-scope` | URL sanitization scope, unrelated to restoration. |
| `sem-security-test-expansion-detection` | Tests expansion detection; blocks-alist still contains full block content for security verification. |
| `sem-url-capture-test-restore-from-llm-unit` | Tests that secret is restored and token is removed; does not check for marker presence. |
| `sem-url-capture-test-restore-integration` | Tests that secret is restored and token is removed; does not check for marker presence. |

### Tests that MUST be modified (replaced)

These tests expect round-trip to restore original content WITH `#begin_sensitive` markers. They must be updated to expect plain text restoration.

| Test | Current Expectation | Required Change |
|------|-------------------|----------------|
| `sem-security-test-tokenize-detokenize-roundtrip` | Round-trip restores original with markers | Update to expect plain text restoration |
| `sem-security-test-position-roundtrip` | Round-trip restores original with markers | Update to expect plain text restoration |
| `sem-router-test-security-block-round-trip` | Round-trip restores original with markers | Update to expect plain text restoration |

### Test Execution

- **Unit tests**: Run by agent after each code change using:
  ```sh
  emacs --batch --load app/elisp/tests/sem-test-runner.el
  ```
- **Integration tests**: Run by human-in-the-loop only. Agent MUST NOT run integration tests. Agent waits for human to run `bash dev/integration/run-integration-tests.sh` and provide feedback before marking tasks complete.

## Integration Test Changes

### Files to Modify

- `dev/integration/testing-resources/inbox-tasks.org` - Add multi-line sensitive block
- `dev/integration/run-integration-tests.sh` - Add order verification and negative marker assertion

### New Inbox Entry (multi-line sensitive)

```org
* TODO Process payment to vendor :task:
  Contact the bookkeeper ask to pay the bill
  #+begin_sensitive
  IBAN: DE89370400440532013000
  ACCOUNT NUMBER: 123456789
  #+end_sensitive
  and sent the pdf to the vendor portal.
```

### New Assertions in run-integration-tests.sh

1. **Negative assertion**: `grep -v '#+begin_sensitive'` should find zero matches in tasks.org output
2. **Order verification**: Verify sensitive keywords appear in same order as in inbox

## Execution Constraints

1. Agent runs unit tests after each code modification
2. Agent does NOT run integration tests
3. Agent does NOT mark implementation as complete until human confirms integration tests pass
4. Human runs integration tests manually and provides feedback to agent

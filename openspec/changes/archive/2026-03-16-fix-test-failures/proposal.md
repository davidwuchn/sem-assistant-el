## Why

4 of 45 ERT tests fail. Root causes:

1. `sem-core-log` uses `cl-return-from` inside a plain `defun`. `cl-return-from` requires a `cl-block`; without one, the macro emits a `throw` with no matching `catch`. The `condition-case` handler `(t nil)` in `sem-core-log` catches it and attempts to evaluate `(t nil)` as a form, which calls `t` as a function → `(void-function t)`. This silently swallows the error, making `sem-core-log` a no-op. All 4 failures trace to this bug.
2. `sem-url-capture-process` calls `gptel-request` directly and synchronously (`call-args: :stream nil`), bypassing `sem-llm-request`. This skips hash tracking and DLQ logging. No test currently covers this path end-to-end.
3. The trafilatura mock in `sem-mock.el` uses `:filter-args` advice on `call-process`. `:filter-args` advisors must return a (possibly modified) argument list — they cannot return a value. The mock therefore never intercepts the return code; the real `call-process` runs and returns its own exit code. Any test depending on `sem-mock-trafilatura-success` or `sem-mock-trafilatura-failure` is silently wrong.

## What Changes

- `sem-core.el`: Wrap `sem-core-log` body in `(cl-block sem-core-log ...)` so that `(cl-return-from sem-core-log nil)` is valid. No other changes to `sem-core-log`.
- `sem-url-capture.el`: Replace the direct `gptel-request` call in `sem-url-capture-process` with `sem-llm-request`. `sem-url-capture--validate-and-save` becomes the success callback passed via the context plist. The function signature of `sem-url-capture--validate-and-save` does not change.
- `sem-mock.el`: Replace `:filter-args` advice with `:override` advice on `call-process` in `sem-mock-trafilatura-success` and `sem-mock-trafilatura-failure`. The override must check `(string= (car args) "trafilatura")` (where `args` is the full `call-process` argument list) and only intercept trafilatura calls; all other `call-process` calls must pass through via `apply #'call-process--original args` or equivalent.

## Capabilities

### New Capabilities

- `sem-url-capture-process-via-sem-llm`: `sem-url-capture-process` routes LLM calls through `sem-llm-request`. Constraints: hash is marked processed on malformed LLM response (DLQ path); hash is NOT marked processed on API error (retry path); `sem-url-capture--validate-and-save` is invoked as the success callback; the fetch step (trafilatura) is unchanged.

### Modified Capabilities

- `sem-core-log`: Wraps its body in `(cl-block sem-core-log ...)`. Behavior is identical to the intended behavior before the bug. The `condition-case` error handler `(t nil)` remains. The `cl-return-from` call at line 93 is preserved as-is.
- `sem-mock-trafilatura-success`: Changes from `:filter-args` to `:override` advice. Writes `output` to the buffer argument (4th arg of `call-process`), returns `0`. Only intercepts when first arg is `"trafilatura"`.
- `sem-mock-trafilatura-failure`: Changes from `:filter-args` to `:override` advice. Returns `exit-code` (non-zero). Only intercepts when first arg is `"trafilatura"`.

## Impact

- Tests fixed: `sem-core-test-log-format-with-tokens`, `sem-core-test-log-format-without-tokens`, `sem-url-capture-test-validate-errors-missing-properties`, `sem-url-capture-test-validate-errors-missing-title`.
- New tests added: `sem-url-capture-test-process-valid-response` (happy path: mock trafilatura success + mock gptel success → validate-and-save called, hash marked), `sem-url-capture-test-process-malformed-response` (DLQ path: mock trafilatura success + mock gptel malformed → hash marked, result nil).
- Out of scope: `sem-router--route-to-task-llm` stub, `sem-core--flush-messages` redefinition in `init.el`, arXiv digest, Docker/cron configuration.
- Zero behavior change in production: `sem-core--ensure-log-headings` succeeds on a writable `/data/` filesystem, so the `cl-return-from` branch was never reached at runtime.
